% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/public.R
\name{mapDiversity}
\alias{mapDiversity}
\title{Map genetic Diversity}
\usage{
mapDiversity(
  ctx,
  sampleSet,
  timePeriods = NULL,
  measures = "ALL",
  aggregate = "Province",
  minAggregateCount = 10,
  showNames = TRUE,
  markerSize = 16,
  markerColours = "red3",
  width = 15,
  height = 15
)
}
\arguments{
\item{ctx}{TBD}

\item{sampleSet}{TBD}

\item{timePeriods}{The list of time period object for partitioning samples into time-interval plots}

\item{measures}{can be "ALL", or any vector containing one or more of ("maxHaploFreq","haploHet", "meanSnpHet","medianDistance")}

\item{aggregate}{TBD}

\item{minAggregateCount}{TBD}

\item{showNames}{TBD}

\item{markerSize}{TBD}

\item{markerColours}{TBD}

\item{width}{The width (in inches) of the map image.}

\item{height}{The height (in inches) of the map image.}
}
\value{
TBD
}
\description{
Map genetic Diversity
}
\examples{
 #TBD
}
