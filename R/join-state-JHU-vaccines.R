#!/usr/bin/Rscript
library(docopt)
library(cli)
suppressMessages( library(tidyverse) )

ps <- cli_process_start; pd <- cli_process_done

'JHU State-data / Vaccine-data Joiner

Usage:
  join-state-JHU-vaccines.R -o <path> --jhu <path> --vax <path> --metadata <path> [--writeMetadata <path>]
  join-state-JHU-vaccines.R (-h | --help)
  join-state-JHU-vaccines.R --version

Options:
  -o <path>               Path to output joined data to.
  --jhu <path>            Path to cleaned JHU state-level data
  --vax <path>            Path to vaccine risk-ratio data
  --metadata <path>       Path to JSON metadata about the cases/deaths of each state
  --writeMetadata <path>  Where to save metadata about all case/death/vaccine data
  -h --help               Show this screen.
  --version               Show version.

' -> doc

args <- docopt(doc, version = 'join-state-JHU-vaccines.R 0.1')

cli_h1("Loading input data")

ps("Loading JHU case-death data from {.file {args$jhu}}")
jhu <- read_csv(
  args$jhu,
  col_types = cols(
    date = col_date(),
    state = col_character(),
    cases = col_number(),
    deaths = col_number(),
    fracpos = col_number(),
    volume = col_number()
  )
)
pd()

ps("Loading vaccine data from {.file {args$vax}}")
vax <- read_csv(
  args$vax,
  col_types = cols(
    Date = col_date(),
    FIPS = col_character(),
    StateName = col_character(),
    RR = col_number()
  )
)
pd()

ps("Loading metadata from {.file {args$metadata}}")
metadata <- jsonlite::read_json(args$metadata, simplifyVector = T)
pd()

ps("Joining JHU and vax data")
jhu_state <- unique(jhu$state)
rr_state <- unique(vax$FIPS)

right_join(
  jhu,
  select(vax, -StateName),
  by = c("date" = "Date", "state" = "FIPS")
) %>%
  filter(state %in% jhu_state &
           state %in% rr_state) -> joined
pd()
        
###############
## Checks    ##
###############
cli_h1("Performing checks")

# Check to make sure each state only has non-missing RRs after the initial
# pre-vaccine-data period of NAs.
ps("No missing RRs after first non-missing RR")
  NAsAfterBeginning <- joined %>% group_by(state) %>% arrange(date) %>%
    summarize(
      NAsAreOnlyAtTheBeginning = 
        # The latest date which contains an NA-valued RR
        max(date[which(is.na(RR))]) <
          # The earliest date which contains a non-missing RR
          min(date[which(!is.na(RR))])
    ) %>% filter(!NAsAreOnlyAtTheBeginning)

  if (nrow(NAsAfterBeginning > 0)) {
    cli_alert_danger("There were missing RRs after the first day of vaccine data for these counties:")
    print(NAsAfterBeginning)
    quit(status = 1)
  }
pd()

ps("No unrealistically high or low RRs ({.code RR<0 | RR>1.5})")
AnyUnrealisticValues <- filter(joined, RR < 0 | RR > 1.5)

if (nrow(AnyUnrealisticValues) > 0) {
  cli_alert_danger("There unrealistic vaccine RRs for these counties:")
  print(AnyUnrealisticValues)
  quit(status = 1)
}
pd()

cli_h1("Processing")

ps("Replacing missing RRs with {.code 1}")
replaced <- replace_na(joined, list(RR = 1))
pd()

cli_h1("Writing")

ps("Writing output to {.file {args$o}}")
write_csv(replaced, args$o)
pd()

if (!is.null(args$writeMetadata)) {
  ps("Writing metadata to {.file {args$writeMetadata}}")
  metadata <- filter(metadata, state %in% unique(replaced$state))
  jsonlite::write_json(metadata, args$writeMetadata, null = "null")
  pd()
}
