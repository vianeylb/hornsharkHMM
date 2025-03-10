% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/exploring_lab_data_dynamic.R
\name{behavior_hist_dynamic}
\alias{behavior_hist_dynamic}
\title{Create histograms from dynamic and ODBA data, for each behavior interval}
\usage{
behavior_hist_dynamic(data, filename)
}
\arguments{
\item{data}{A dataframe with columns Behavior, X_dynamic,
Y_dynamic, Z_dynamic, ODBA}

\item{filename}{String containing the first part of filename for the
image files to be created}
}
\value{
Several image files. Each image file contains histograms
aggregating a given data type (X_dynamic, Y_dynamic, Z_dynamic, ODBA)
over a given behavior.
}
\description{
A behavior interval is a time interval in which the behavior remains
constant.
Each behavior interval is labelled by a number, in chronological order.
Each plot contains histograms aggregating a given data type over
a given behavior.
If there are many behavior intervals for a given behavior, the
plot may be hard to read.
}
\examples{
filename <- "Custom_Lady_27Mar17_dynamic.csv"
data <- read.csv(filename)
labelled_data <- data \%>\% filter(!is.na(Behavior))
behavior_hist_dynamic(labelled_data, "Lady_27Mar17_histogram_behavior")
}
