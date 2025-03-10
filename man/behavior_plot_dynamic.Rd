% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/exploring_lab_data_dynamic.R
\name{behavior_plot_dynamic}
\alias{behavior_plot_dynamic}
\title{Create line plots from dynamic and ODBA data, which are colored by behavior}
\usage{
behavior_plot_dynamic(data, filename)
}
\arguments{
\item{data}{A dataframe with columns Time, Behavior, X_dynamic,
Y_dynamic, Z_dynamic, ODBA}

\item{filename}{String containing the first part of filename for the
image files to be created}
}
\value{
One image file containing line plots for X_dynamic, Y_dynamic, Z_dynamic,
and a separate image file containing a line plot for ODBA. Each line plot is colored
by behavior.
}
\description{
Create line plots from dynamic and ODBA data, which are colored by behavior
}
\examples{
filename <- "Custom_Lady_27Mar17_dynamic.csv"
data <- read.csv(filename)
labelled_data <- data \%>\% filter(!is.na(Behavior))
behavior_plot_dynamic(labelled_data, "Lady_27Mar17_plot_behavior")
}
