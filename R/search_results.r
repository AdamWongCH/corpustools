featureHits <- function(hits, queries) {
  ## S3 class
  if(is.null(hits)) hits = data.frame(code=character(), feature=character(), doc_id=character(), sent_i = numeric(), hit_id=numeric(), i=numeric())
  hits = as.data.frame(hits)
  if (!'sent_i' %in% colnames(hits)) {
    hits$sent_i = if(nrow(hits) == 0) numeric() else NA
  }
  hits = hits[,c('code','feature','doc_id','sent_i','word_i', 'hit_id','i')]
  fh = list(hits=hits, queries=queries)
  class(fh) = c('featureHits', class(fh))
  if(!is.featureHits(fh)) stop('Not a proper featureHits object')
  fh
}

is.featureHits <- function(fh, ...) {
  if (!methods::is(fh$hits, 'data.frame')) return(FALSE)
  if (!all(c('code','feature','i','doc_id','hit_id', 'sent_i', 'word_i') %in% colnames(fh$hits))) return(FALSE)
  if (!all(c('keyword','condition','code','condition_once','subset_tokens','subset_meta') %in% colnames(fh$queries))) return(FALSE)
  return(TRUE)
}

#' S3 print for featureHits class
#'
#' @param x a featureHits object, as returned by \link{tCorpus$search_features}
#' @param ... not used
#'
#' @export
print.featureHits <- function(x, ...){
  if(!is.featureHits(x)) stop('Not a proper featureHits object')
  n_hits = length(unique(x$hits$hit_id))
  n_docs = length(unique(x$hits$doc_id))
  n_sent = if(any(is.na(x$hits$sent_i))) NULL else nrow(x$hits[,c('doc_id','sent_i')])
  cat(n_hits, 'hits (in', n_docs, 'documents')
  if(!is.null(n_sent)) cat(' /', n_sent, 'sentences)\n') else cat(')\n')
}

#' S3 summary for featureHits class
#'
#' @param object a featureHits object, as returned by \link{tCorpus$search_features}
#' @param ... not used
#'
#' @export
summary.featureHits <- function(object, ...){
  doc_id = sent_i = hit_id = NULL ##  used in data.table syntax, but need to have bindings for R CMD check

  #if(is.null(x$hits)) return(NULL)
  if (!any(is.na(object$hits$sent_i))){
    object$hits$sent_i = paste(object$hits$doc_id, object$hits$sent_i, sep='_')
    agg = data.table(object$hits)[, list(hits = length(unique(hit_id)),
                              sentences = length(unique(sent_i)),
                              documents = length(unique(doc_id))),
                              by='code']
  } else {
    agg = data.table(object$hits)[, list(hits = length(unique(hit_id)),
                              documents = length(unique(doc_id))),
                           by='code']
  }
  as.data.frame(agg)
}

contextHits <- function(hits, queries) {
  ## S3 class
  if(is.null(hits)) hits = data.frame(code=character(), doc_id=character(), sent_i = numeric())
  hits = as.data.frame(hits)
  if (!'sent_i' %in% colnames(hits)) {
    hits$sent_i = if(nrow(hits) == 0) numeric() else NA
  }
  hits = hits[,c('code','doc_id','sent_i')]

  ch = list(hits=hits, queries=queries)
  class(ch) = c('contextHits', class(ch))
  if(!is.contextHits(ch)) stop('Not a proper contextHits object')
  ch
}

is.contextHits <- function(ch, ...) {
  if (!methods::is(ch$hits, 'data.frame')) return(FALSE)
  if (!all(c('code','doc_id','sent_i') %in% colnames(ch$hits))) return(FALSE)
  if (!all(c('query','code') %in% colnames(ch$queries))) return(FALSE)
  return(TRUE)
}

#' S3 print for contextHits class
#'
#' @param x a contextHits object, as returned by \link{tCorpus$search_contexts}
#' @param ... not used
#'
#' @export
print.contextHits <- function(x, ...){
  if(!is.contextHits(x)) stop('Not a proper featureHits object')
  n_docs = length(unique(x$hits$doc_id))
  n_sent = if(any(is.na(x$hits$sent_i))) NULL else nrow(x$hits[,c('doc_id','sent_i')])
  cat(n_docs, 'documents')
  if(!is.null(n_sent)) cat(' /', n_sent, 'sentences') else cat('\n')
}

#' S3 summary for contextHits class
#'
#' @param object a contextHits object, as returned by \link{tCorpus$search_contexts}
#' @param ... not used
#'
#' @export
summary.contextHits <- function(object, ...){
  #if(is.null(object$hits)) return(NULL)
  doc_id = sent_i = NULL  ## used in data.table syntax, but need to have bindings for R CMD check

  if (!any(is.na(object$hits$sent_i))){
    object$hits$sent_i = paste(object$hits$doc_id, object$hits$sent_i, sep='_')
    object = data.table(object$hits)[, list(sentences = length(unique(sent_i)),
                              documents = length(unique(doc_id))),
                           by='code']

  } else {
    object = data.table(object$hits)[, list(documents = length(unique(doc_id))),
                           by='code']
  }
  as.data.frame(object)
}

