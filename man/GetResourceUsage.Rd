% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/greatlakes_resource_usage.R
\name{GetResourceUsage}
\alias{GetResourceUsage}
\title{Get memory usage and run time for a Great Lakes sbatch job given the job id}
\usage{
GetResourceUsage(jobId)
}
\arguments{
\item{jobId}{Character or numeric}
}
\value{
Numeric Vector. Memory in GB and time in hours.
}
\description{
This function needs to be run from the command line, not within
  an Rstudio session due to a call of system(). T
}
