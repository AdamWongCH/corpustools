get_dtm <- function(tc, feature, context_level=c('document','sentence'), weight=c('termfreq','docfreq','tfidf','norm_tfidf'), drop_empty_terms=T, form=c('Matrix', 'tm_dtm', 'quanteda_dfm'), subset_tokens=NULL, subset_meta=NULL, context=NULL, context_labels=T, feature_labels=T, ngrams=NA, ngram_before_subset=F){
  form = match.arg(form)
  if(form == 'tm_dtm') if(!requireNamespace('tm', quietly = T)) stop('To use the tm_dtm output form, you need to have the tm package installed.')
  if(form == 'quanteda_dfm') if(!requireNamespace('quanteda', quietly = T)) stop('To use the quanteda_dtm output form, you need to have the quanteda package installed.')
  is_tcorpus(tc, T)

  weight = match.arg(weight)
  context_levels = match.arg(context_level)

  i = if (!is.null(context)) context else tc$context(context_level, with_labels = context_labels)
  if (!methods::is(i, 'factor')) i = fast_factor(i)

  if (!is.null(subset_tokens) | !is.null(subset_meta)) {
    evalhere_subset_tokens = subset_tokens
    evalhere_subset_meta = subset_meta
    sub_i = tc$subset_i(subset = evalhere_subset_tokens, subset_meta = evalhere_subset_meta)
    all_i = i
    i = droplevels(all_i[sub_i])
  } else {
    sub_i = 1:tc$n
  }

  feature = tc$get(feature)

  if(!methods::is(feature, 'factor')) feature = fast_factor(feature)
  if (!is.na(ngrams)) {
    filter = if (ngram_before_subset) NULL else sub_i
    feature = grouped_ngrams(feature, group = i, n = ngrams, filter = filter, label = feature_labels) ## designed to work fast if no labels are needed
  }

  if (!is.null(subset_tokens) | !is.null(subset_meta)) { ## if a subset is used, calculate the idf here for the entire corpus
    idf = get_idf(all_i, feature)
  } else idf = NULL

  feature = feature[sub_i]
  if(drop_empty_terms & methods::is(feature, 'factor')) feature = droplevels(feature)
  notNA = !is.na(feature)

  m = Matrix::spMatrix(length(levels(i)), length(levels(feature)),
                       as.numeric(i)[notNA], as.numeric(feature)[notNA],
                       rep(1, sum(notNA)))

  dimnames(m) = list(levels(i), levels(feature))

  m = weight_dtm(m, weight, idf=idf)

  if (form == 'tm_dtm'){
    m = tm::as.DocumentTermMatrix(m, weight=tm::weightTf)
    if(weight == 'tfidf') attributes(m)$weighting = c("term frequency - inverse document frequency", "tf-idf")
    if(weight == 'tfidf_norm') attributes(m)$weighting = c("term frequency - inverse document frequency (normalized)", "tf-idf")
    if(!weight %in% c('termfreq','tfidf', 'tfidf_norm')) attributes(m)$weighting = c(weight, weight)
  }
  if (form == 'quanteda_dfm') m = methods::new("dfmSparse", methods::as(m, 'dgCMatrix'))

  m
}

get_idf <- function(context, feature) {
  idf = unique(cbind(context=context, feature=as.character(feature)))
  idf = table(idf[,'feature'])
  N = length(unique(context))
  log2(N / idf)
}

weight_dtm <- function(m, weight, idf=NULL){
  m = methods::as(m, 'dgTMatrix')
  if(weight %in% c('tfidf', 'norm_tfidf')){
    if(weight == 'norm_tfidf') m@x = m@x / rowSums(m)[m@i+1]
    if(is.null(idf)) {
      idf = log2(nrow(m)/colSums(m > 0))
    } else {
      idf = as.numeric(idf[match(colnames(m), names(idf))])
    }
    m@x = m@x * idf[m@j+1]
  }
  if(weight == 'docfreq') {
    m = m > 0
  }
  methods::as(methods::as(m,'dgCMatrix'), 'dgTMatrix')
}

tm_dtm_to_dgTMatrix <- function(dtm){
  sm = Matrix::spMatrix(nrow(dtm), ncol(dtm), dtm$i, dtm$j, dtm$v)
  rownames(sm) = rownames(dtm)
  colnames(sm) = colnames(dtm)
  sm
}
