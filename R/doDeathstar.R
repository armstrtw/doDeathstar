registerDoDeathstar <- function(cluster,exec.port=6000L,status.port=6001L) {
    setDoPar(doDeathstar, data=list(cluster=cluster,exec.port=exec.port,status.port=status.port))
}

doDeathstar <- function(obj, expr, envir, data) {
  # set the default mclapply options
  set.seed <- TRUE
  silent <- FALSE

  if (!inherits(obj, 'foreach'))
    stop('obj must be a foreach object')

  it <- iter(obj)
  argsList <- as.list(it)
  accumulator <- makeAccum(it)

  # make sure all of the necessary libraries have been loaded
  for (p in obj$packages)
    library(p, character.only=TRUE)

  FUN <- function(x,ex,env) {
      eval(ex,x)
  }

  ## execute the tasks
  results <- zmq.cluster.lapply(data$cluster,argsList,FUN,ex=as.expression(expr),exec.port=data$exec.port,status.port=data$status.port)

  # call the accumulator with all of the results
  tryCatch(accumulator(results, seq(along=results)), error=function(e) {
    cat('error calling combine function:\n')
    print(e)
    NULL
  })

  # check for errors
  errorValue <- getErrorValue(it)
  errorIndex <- getErrorIndex(it)

  # throw an error or return the combined results
  if (identical(obj$errorHandling, 'stop') && !is.null(errorValue)) {
    msg <- sprintf('task %d failed - "%s"', errorIndex,
                   conditionMessage(errorValue))
    stop(simpleError(msg, call=expr))
  } else {
    getResult(it)
  }
}
