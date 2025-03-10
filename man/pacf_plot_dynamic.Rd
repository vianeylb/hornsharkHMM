% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/exploring_lab_data_dynamic.R
\name{pacf_plot_dynamic}
\alias{pacf_plot_dynamic}
\title{Create PACF plots from dynamic and ODBA data}
\usage{
pacf_plot_dynamic(data, filename)
}
\arguments{
\item{data}{A dataframe with columns X_dynamic,
Y_dynamic, Z_dynamic, ODBA}

\item{filename}{String containing the first part of filename for the
image files to be created}
}
\value{
One image file containing PACF plots for X_dynamic, Y_dynamic, Z_dynamic,
and a separate image file containing a PACF plot for ODBA
}
\description{
Create PACF plots from dynamic and ODBA data
}
\examples{
filename <- "Custom_Lady_27Mar17_dynamic.csv"
data <- read.csv(filename)
pacf_plot_dynamic(data, "Lady_27Mar17_pacf")
}
