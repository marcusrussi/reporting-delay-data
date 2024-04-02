# covidestim-sources

This repository provides a way to clean various input data used for the
`covidestim` model, producing the following easy-to-use outcomes:

- **Cases**
- **Deaths**
- **Vaccination-related risk ratio**
- **Vaccinations and boosters adminstered**
- **Hospitalizations**

These data are offered at the following timeframes:

| Outcome              | Daily  | Weekly |
|----------------------|--------------|-------------|
| **Cases**            | ✓            | ✓           |
| **Deaths **          | ✓            | ✓           |
| **Risk-ratio**       | ✓            | ✓           |
| **Vax-boost**        | ✓            | ✓           |
| **Hospitalizations** |             | ✓           |


Hospitalizations data *were* reported Friday-Thursday until June 19, 2023. Then they switched to a Sunday-Saturday reporting scheme.
The weekly CDC case data is reported at a weekly Thursday-Wednesday routine.
We match the hospitalization weeks to the closest case report week. That is, the hospitalization reports from Sunday February 5-Saturday February 11 are matched to the case reports from Thursday February 2 - Wednesday February 8 (2023 reference dates).

## Usage and dependencies

This repository is essentially a series of GNU Make targets (see `makefile`),
which depend on the results of HTTP requests, as well as data sources in
`data-sources/`. None of the "cleaned" data are committed to the repository;
you need to make it yourself to produce it.

First, install [Git LFS](https://git-lfs.github.com/).

Then, clone the repository and initialize the Git submodules, which track some
of our external data sources:

```bash
git clone https://github.com/covidestim/covidestim-sources && cd covidestim-sources
git submodule init
git submodule update --remote # This will take 5-30 minutes
```

Then, make sure you have the neccessary R packages installed. These are:

- `tidyverse`
- `cli`
- `docopt`
- `sf`
- `vaccineAdjust`: Not on CRAN. To install: `devtools::install_github("covidestim/vaccineAdjust")`
- `raster`
- `spdep`
- `usdata`

You can install them in the R console: `install.packages(c('tidyverse', 'cli', 'docopt', 'sf', 'raster', 'spdep', 'usdata'))`.

Finally, attempt to make the most important targets. Note, you will need GNU Make >=4.3
installed, which does not ship with OS X. 
Be aware that MacOS system can come without wget installed, so make sure to have installed you can do it by typing on terminal: `brew install wget`.
We identify a few different endpoints for both the county and the state geographies. In the following we describe the targets for the counties.
The first target is daily and weekly data suitable for the covidestim website runs. This data relies on limited sources and has date constraints.
The second set of targets is daily and weekly data suitable for manuscripts and additional analyses, and is as complete as possible, extending the time series as long as available. This includes multiple data sources and imputes data for missing counties in Nebraska for example.

```bash
# Make all primary outcomes
make -Bj data-products/{daily-fips-covidestim.csv daily-states-covidestim.csv}
make -Bj data-products/{weekly-fips-covidestim.csv weekly-states-covidestim.csv}
make -Bj data-products/{daily-fips-full.csv daily-states-full.csv}
make -Bj data-products/{weekly-fips-full.csv weekly-states-full.csv}
```

For the `daily` data sources, the `date` variable indicates the date of occurrence.
For the `weely` data sources, the `date` variable indicates the last date of the week that the data refers to.
For the `covidestim` data sources, the data are filtered to be appropriate for running a covidestim model. For `daily` datasets, this means that the data is right-censored at December 1, 2021, and for `weekly` datasets, the corresponding left-censoring at December 1, 2021. (The `covidestim` daily model is not appropriate after the Omicron variants were introduced, while the `weekly` model has assumptions specific for Omicron variants).
The `covidestim` data sources are finally trimmed such that all relevant variables are observed.
The `full` datasets have the full, unfiltered data; that is, for vaccination and case data, the reporting frequency changes from daily to weekly, Nebraska counties are imputed and a few additional counties are considered from the NYTimes database. 

## Repository structure

- `makefile`: The project makefile. If you're confused about how a piece of data
  gets cleaned, go here first. If you've never read a Makefile before, it's
  advisable to read an introduction to Make, like [this one](https://web.mit.edu/gnu/doc/html/make_2.html).
- `data-products/`: All cleaned data is written to this directory. Some recipes
  will also products metadata, which will always have a `.json` extension.
- `data-sources/`: All git submodules are stored here, as well as static files
  used in recipes, like population sizes, polygons, and records of periods
  of nonreporting.
- `example-output/`: Some example cleaned data, for reference
- `R/`: All data cleaning scripts live here

## Keeping your data sources up-to-date

Data sources will **not** automatically update, and thus, `make` will not
normally do anything if you attempt to remake a target! This is undesirable if
you believe there may be newer versions of data sources available. To pull new
data from sources backed by submodules, run:

```bash
git submodule update --remote
```

And, use `make -B` to force targets to be remade, like so:

```bash
make -B data-products/case-death-rr.csv
```

## Data sources

All data sources for the cleaned data are either:

- Committed to the repository in `data-sources/`
- Committed to the repository in `data-sources/`, but backed by [Git LFS][lfs]
- Accessed through HTTP requests in the `makefile` or from within R scripts
- Committed to the repository as Git submodules in `data-sources/`

| Data                                      | Used for                                                                                      | Accessed through                                                                        | Frequency of update |
|-------------------------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|---------------------|
| Johns Hopkins CSSE                        | Cases, Deaths    | Submodule `data-sources/jhu-data`      | Stale -- data is daily, until February 14, 2023          |
| Covid Tracking Project                    | Cases, Deaths (2021-02 - 2021-06)                                                             | HTTP, `api.covidtracking.com`                                                           | No longer updated   |
| NYTimes covid data                        | *Nothing, but a future merge will use it to supplement counties missing from the JHU dataset* | Submodule, `data-sources/nyt-data`                                                      | Stale. Data is daily, until June 2021          |
| USCB county, state population estimates   | Everything                                                                                    | `data-sources/{fips,state}pop.csv`, reformatted from [.xls][xlspop]                     | *1/yr?*             |
| DHHS facility-level hospitalizations data | Hospitalizations                                                                              | HTTP, `healthdata.gov/api`                                                              | **1/wk**            |
| Dartmouth Atlas Zip-HSA-HRR crosswalk     | Hospitalizations (agg/disagg)                                                                 | `data-sources/ZipHsaHrr18.csv`, downloaded from [dartmouthatlas.org][da]                | *1/yr?*             |
| Dartmouth Atlas HSA polygons              | Hospitalizations (agg/disagg)                                                                 | `data-sources/hsa-polygons/` ([Git LFS][lfs]), downloaded from [dartmouthatlas.org][da] | *1/yr?*             |
| Census Block Group polygons               | Hospitalizations (agg/disagg)                                                                 | `data-sources/cbg-polygons/` ([Git LFS][lfs]),  downloaded from [TIGER][tiger]          | *1/yr?*             |
| Census Block Group popsize                | Hospitalizations (agg/disagg)                                                                 | `data-sources/population_by_cbg.csv/`, extracted from [TIGER][tiger]                    | *1/yr?*             |
| Vaccination adjustments                   | Vaccination adjustments                                                                       | `data-sources/vaccines-counties.csv`                                                    | Static w/ data through Dec 2023 |
| Data.CDC.gov                              | Booster and vaccination data                                                                  | `data-sources/cdc-vax-boost-state.csv/`, extracted from [cdc-states][cdcstate] and `data-sources/cdc-vax-boost-county.csv` extracted from [cdc-counties][cdcfips] | Monthly. Data is daily until June 2022, then weekly until May 2023, then monthly  |
| Data.CDC.gov                              | Case data, after February 14, 2023                                                              |  [cdc-state-cases][cdcstatecase] and  [cdc-counties-cases][cdcfipscase] | stale -- data is weekly until May 11, 2023  |

[xlspop]: https://www.census.gov/geographies/reference-files/2020/demo/popest/2020-fips.html
[da]: https://data.dartmouthatlas.org/supplemental/
[lfs]: https://git-lfs.github.com/
[tiger]: https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2021&layergroup=Census+Tracts
[cdcstate]: https://data.cdc.gov/Vaccinations/COVID-19-Vaccinations-in-the-United-States-Jurisdi/unsk-b7fc
[cdcfips]: https://data.cdc.gov/Vaccinations/COVID-19-Vaccinations-in-the-United-States-County/8xkx-amqh
[cdcfipscase]: https://data.cdc.gov/Public-Health-Surveillance/United-States-COVID-19-Community-Levels-by-County/3nnm-4jni
[cdcstatecase]: https://data.cdc.gov/Case-Surveillance/Weekly-United-States-COVID-19-Cases-and-Deaths-by-/pwn4-m3yp

Some data sources are tracked as git submodules, and other sources, being 
accessed through APIs, are fetched over HTTP. Large static files are stored
through [Git LFS][lfs].

The included `makefile` provides a common interface for directing the fetching
and cleaning of all data sources.

## Data sources

-   **`data-sources/vaccines-counties`** A cached file containing daily RR adjustments to the transition probabilities for each state and county, up until December 31, 2022. This file is rendered by running vaccineAdjust::run(), with data up until December 1, 2021, and freezing the final RR adjustment. After December 1, 2021, vaccination adjustments occur within the covidestim model.

## Targets

- **`make data-products/daily-fips-covidestim.csv`**
  Reads the JHU county level case/death data, the CDC vaccination data,
  the static IFR adjustments, and joins these together.
  
- **`make data-products/daily-fips-full.csv`**
  Read the JHU county level case/death data, the CDC cases data, the NYT case/death data and imputes the Nebraska county data using the state average.
  Combines the above with the CDC vaccination data, static IFR adjustments.

- **`make data-products/weekly-fips-covidestim.csv`**
  Reads and combines the JHU county level case/death data and the CDC cases data.
  the static IFR adjustments, and joins these together.
  
- **`make data-products/weekly-fips-full.csv`**
  Read the JHU county level case/death data, the CDC cases data, the NYT case/death data and imputes the Nebraska county data using the state average.
  Combines the above with the CDC vaccination data, static IFR adjustments.
  
## Targets (legacy)

- **`make data-products/case-death-rr-boost-hosp.csv`**  
  Reads cleaned archived JHU county-level case/death data. 
  Joins by location and date with static 
  vaccine IFR adjustments from `data-sources/vaccines-counties` and the 
  cleaned CDC `vax-boost-county.csv`.
  Weekly aggregates are joined with the cleaned `hhs-hospitalizations-by-county.csv`. 
  Any metadata for counties included in the cleaned data will
  be stored in `case-death-rr-boost-hosp-metadata.json`. 
  Joins the weekly CDC case data from `data-sources/cdc-cases-raw.csv`

- **`make data-products/case-death-rr-boost-hosp-state.csv`**  
  Reads cleaned archived JHU state-level data, splicing in archived Covid Tracking Project data.
  For details on this, see the `makefile`. 
  Joins by location and date with static vaccine IFR adjustments from 
  `data-sources/vaccines-counties` and the cleaned CDC `vax-boost-state.csv`.
  Weekly aggregates are joined with the cleaned `hhs-hospitalizations-by-state.csv`.
  Any metadata for counties included in the cleaned
  data will be stored in `case-death-rr-boost-hosp-state-metadata.json`. 
  Joins the weekly CDC case data from `data-sources/cdc-cases-state-raw.csv`

- **`make data-products/nyt-counties.csv`**  
  Clean NYT county-level case/death data. Writes `nyt-counties-rejects.csv`.

- **`make data-products/hhs-hospitalizations-by-state.csv`**  
  State-level aggregation of county level hospitalization data. 
  
- **`make data-products/hhs-hospitalizations-by-county.csv`**  
  County-level aggregation of facility level hospitalization data. See the next
  section for details on how this is done.

- **`make data-products/hhs-hospitalizations-by-facility.csv`**  
  Cleans facility-level data from DHHS's API and annotates each faility with an
  HSA id. Also, computes .min and .max columns to compensate for censoring done
  when there are 1-3 hospitalizations in a given week.

## Hospitalizations data pipeline

Key document: **[COVID-19 Guidance for Hospital Reporting and FAQs For
Hospitals, Hospital Laboratory, and Acute Care Facility Data Reporting][hhs]**,
January 6, 2022 revision

We source hospitalizations data from the official [HHS facility-level dataset][hhs-data].
In order to be useful to our model, we transform these data into a county-level
dataset. 

[hhs-data]: https://healthdata.gov/stories/s/nhgk-5gpv

### Outcome format

Outcomes are presented across 3-4 variables. For an outcome `name`, the 
following variables may be present:

- `{name}`: The outcome itself, including censored data. This means that if a
  facility reports `-999999` for that week, the `name` outcome will be equal
  to `-999999`.

- `{name}_min`: The smallest the outcome could be - all censored values, which each
  represent a possible range of 1-3, will be resolved to 1.

- `{name}_max`: The largest the outcome could be if all censored values are resolved to
  3.

- `{name}_max2`: The largest the outcome could be if all censored valeus are resolved
  to 3 and any missing days are imputed using the average of the present days.  

  **Note**: This quantity is not meaningful for the following averaged
  prevalence outcomes, because they are already averaged across the number of
  days reported by the facility that week (which is not necessarily 7). For
  these outcomes, `{name}_max == {name}_max2`.

  - `averageAdultICUPatientsConfirmed`
  - `averageAdultICUPatientsConfirmedSuspected` 
  - `averageAdultInpatientsConfirmed`
  - `averageAdultInpatientsConfirmedSuspected`

### Outcomes table

| Variable                                    | Meaning                                                                                                 | `min`/`max` | `max2`         |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------|-------------|----------------|
| `fips`                                      | FIPS code of the county                                                                                 |             |                |
| `weekstart`                                 | YYYY-MM-DD of the firs date in the week                                                                 |             |                |
| `admissionsAdultsConfirmed`                 | # admissions of adults with confirmed[^1] Covid                                                         | ✓           | ✓              |
| `admissionsAdultsSuspected`                 | # admissions of adults with suspected[^2] Covid                                                         | ✓           | ✓              |
| `admissionsPedsConfirmed`                   | # admissions of peds with confirmed[^1] Covid                                                           | ✓           | ✓              |
| `admissionsPedsSuspected`                   | # admissions of peds with suspected[^2] Covid                                                           | ✓           | ✓              |
| `averageAdultICUPatientsConfirmed`          | Average number of ICU beds occupied by adults with confirmed[^1] covid that week                        | ✓           | equal to `max` |
| `averageAdultICUPatientsConfirmedSuspected` | Average number of ICU beds occupied by adults with confirmed or suspected[^1][^2] covid that week       | ✓           | equal to `max` |
| `averageAdultInpatientsConfirmed`           | Average number of inpatient beds occupied by adults with confirmed[^1] Covid that week                  | ✓           | equal to `max` |
| `averageAdultInpatientsConfirmedSuspected`  | Average number of inpatient beds occupied by adults with confirmed[^1] or suspected[^2] Covid that week | ✓           | equal to `max` |
| `covidRelatedEDVisits`                      | Total number of ED visits that week related to Covid[^3]                                                | ✓           |                |

[^1]: Definition of "Laboratory-confirmed Covid":  
  ![Definition of "Laboratory-confirmed covid"](/img/lab-confirmed-covid.png)
  Source: Page 44, [HHS hospital reporting guidance][hhs]

[^2]: Definition of "suspected Covid":  
  "“Suspected” is defined as a person who is being managed as though he/she has
  COVID-19 because of signs and symptoms suggestive of COVID-19 but does not
  have a laboratory-positive COVID-19 test result."  
  Source: Page 14, [HHS hospital reporting guidance][hhs]

[^3]: Definition of "related to Covid":  
  "Enter the total number of ED visits who were seen on the previous calendar
  day who had a visit related to suspected or laboratory-confirmed COVID-19.
  Do not count patients who receive a COVID-19 test solely for screening
  purposes in the absence of COVID-19 symptoms."  
  Source: Page 14, [HHS hospital reporting guidance][hhs]

[hhs]: https://www.hhs.gov/sites/default/files/covid-19-faqs-hospitals-hospital-laboratory-acute-care-facility-data-reporting.pdf

### Geographic aggregation/disaggregation

<b style="color: grey;">County boundaries</b>, <b style="color: red;">HSA boundaries</b>, <b style="color: blue;">CBG boundaries</b>
![Map of county, HSA, CBG borders](/img/agg-disagg.png)

Simply identifying which county each facility lies within and then summing
across all facilities in a county carries the following drawbacks:

- It ignores the fact that the hospital may be treating patients from other
  counties.

- It ignores the fact that patients from one county may be treated at a
  hospital in an adjacent (or even non-adjacent) county.

These two issues will cause particularly large problems (biases) when:

- There are major medical centers in the area, which are more likely to take
  the lion's share of severe patients during times of peak Covid prevalence.

- There are small or sparsely-populated counties, where residents may have
  to travel outside of their county to seek hospital care.

To help solve this problem, we rely on a dataset maintained by the [Dartmouth
Atlas][da] which defines geographic units called **Hospital Service Areas
(HSA)**.  These service areas are meant to represent a notion of a catchment
area for each hospital:

> Hospital service areas (HSAs) are local health care markets for hospital
> care. An HSA is a collection of ZIP codes whose residents receive most of
> their hospitalizations from the hospitals in that area. HSAs were defined by
> assigning ZIP codes to the hospital area where the greatest proportion of
> their Medicare residents were hospitalized. Minor adjustments were made to
> ensure geographic contiguity. Most hospital service areas contain only one
> hospital. The process resulted in 3,436 HSAs.

Importantly, HSA's are only an approximation of a catchment area, and since a
patient may very well travel outside of the "catchment area" for care with some
nonzero probability, the concept of a catchment area as "patient always goes to
a hospital in this polygon" has inherent limitations as far as fully capturing
patient facility choice. See [this 2015 paper][paper] by Kilaru and Carr for a
discussion of these problems.

#### Methodology

![Diagram of HSA => FIPS process](/img/hospitalizations.png)

Nonetheless, we use HSA's as our aggregate geographical unit because we believe
that it is a better representation of a catchment area than what we would get
by simply drawing the county-border enclosing each facility. To leverage these
HSAs to create county-level hospitalizations data, We:

1. Aggregate facility-level data to the HSA level
2. Fracture the HSAs using county boundaries
3. Use CBG population data to divide the outcomes from fractured HSA's into
   the intersecting counties in a population-proportional manner. Note that the CBG population is not present for D.C. in our dataset, so we manually add the D.C. population for the corresponding HSA.
[paper]: https://pubmed.ncbi.nlm.nih.gov/25961661/
[da]: https://www.dartmouthatlas.org/faq/
