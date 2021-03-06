?print

#' Create a tCorpus
#'
#' @rdname create_tcorpus
#'
#' @param x main input. can be a character (or factor) vector where each value is a full text, or a data.frame that has a column that contains full texts.
#' @param meta A data.frame with document meta information (e.g., date, source). The rows of the data.frame need to match the values of x
#' @param split_sentences Logical. If TRUE, the sentence number of tokens is also computed.
#' @param max_words An integer. Limits the number of words per document to the specified number
#' @param doc_id if x is a character/factor vector, doc_id can be used to specify document ids. This has to be a vector of the same length as x
#' @param doc_column If x is a data.frame, this specifies the column with the document ids.
#' @param text_columns if x is a data.frame, this specifies the column(s) that contains text. The texts are paste together in the order specified here.
#' @param max_sentences An integer. Limits the number of sentences per document to the specified number. If set when split_sentences == FALSE, split_sentences will be set to TRUE.
#' @param verbose If TRUE, report progress
#' @param ... not used
#'
#' @export
#' @name create_tcorpus
create_tcorpus <- function(x, ...) {
  UseMethod('create_tcorpus')
}

#' @rdname create_tcorpus
#' @export
create_tcorpus.character <- function(x, doc_id=1:length(x), meta=NULL, split_sentences=F, max_sentences=NULL, max_words=NULL, verbose=F, ...) {
  if (any(duplicated(doc_id))) stop('doc_id should not contain duplicate values')
  if (!is.null(meta)){
    if (!methods::is(meta, 'data.frame')) stop('"meta" is not a data.frame or data.table')
    if (!nrow(meta) == length(x)) stop('The number of rows in "meta" does not match the number of texts in "x"')
    if (!'doc_id' %in% colnames(meta)) meta = cbind(doc_id=doc_id, meta)
    meta = data.table::data.table(meta, key = 'doc_id')
  } else {
    if (!length(doc_id) == length(x)) stop('"doc_id" is not of the same length as "x"')
    meta = data.table::data.table(doc_id=doc_id, key = 'doc_id')
  }
  meta$doc_id = as.character(meta$doc_id) ## prevent factors, which are unnecessary here and can only lead to conflicting levels with the doc_id in data

  tCorpus$new(data = data.table::data.table(tokenize_to_dataframe(x, doc_id=doc_id, split_sentences=split_sentences, max_sentences=max_sentences, max_words=max_words, verbose=verbose)),
              meta = base::droplevels(meta))
}

#' @rdname create_tcorpus
#' @export
create_tcorpus.factor <- function(x, doc_id=1:length(x), meta=NULL, split_sentences=F, max_sentences=NULL, max_words=NULL, verbose=F, ...) {
  create_tcorpus(as.character(x), doc_id=doc_id, meta=meta, split_sentences=split_sentences, max_sentences=max_sentences, max_words=max_words, verbose=verbose)
}


#' @rdname create_tcorpus
#' @export
create_tcorpus.data.frame <- function(x, text_columns='text', doc_column=NULL, split_sentences=F, max_sentences=NULL, max_words=NULL, ...) {
  for(cname in text_columns) if (!cname %in% colnames(x)) stop(sprintf('text_column "%s" not in data.frame', cname))

  if (length(text_columns) > 1){
    text = apply(x[,text_columns], 1, paste, collapse = '\n\n')
  } else {
    text = x[[text_columns]]
  }

  doc_id = if (is.null(doc_column)) 1:nrow(x) else x[[doc_column]]

  create_tcorpus(text,
                 doc_id = doc_id,
                 meta = x[,!colnames(x) %in% c(text_columns, doc_column), drop=F],
                 split_sentences = split_sentences, max_sentences = max_sentences, max_words = max_words)
}

#' Create a tcorpus based on tokens (i.e. preprocessed texts)
#'
#' @param tokens A data.frame in which rows represent tokens, and columns indicate (at least) the document in which the token occured (doc_col) and the position of the token in that document or globally (word_i_col)
#' @param doc_col The name of the column that contains the document ids/names
#' @param word_i_col The name of the column that contains the positions of words. If NULL, it is assumed that the data.frame is ordered by the order of words and does not contain gaps (e.g., filtered out words)
#' @param sent_i_col Optionally, the name of the column that indicates the sentences in which tokens occured.
#' @param meta Optionally, a data.frame with document meta data. Needs to contain a column with the document ids (with the same name)
#' @param meta_cols Alternatively, if there are document meta columns in the tokens data.table, meta_cols can be used to recognized them. Note that these values have to be unique within documents.
#' @param feature_cols Optionally, specify which columns to include in the tcorpus. If NULL, all column are included (except the specified columns for documents, sentences and positions)
#' @param sent_is_local Sentences in the tCorpus must be locally unique within documents. If sent_is_local is FALSE, then sentences are made sure to be locally unique. However,  it is then assumed that the first sentence in a document is sentence 1, which might not be the case if tokens (input) is a subset. If you know for a fact that the sentence column in tokens is already locally unique, you can set sent_is_local to TRUE to keep the original sent_i values.
#' @param word_is_local Same as sent_is_local, but or word_i
#'
#' @export
tokens_to_tcorpus <- function(tokens, doc_col='doc_id', word_i_col=NULL, sent_i_col=NULL, meta=NULL, meta_cols=NULL, feature_cols=NULL, sent_is_local=F, word_is_local=F) {
  tokens = data.table::as.data.table(tokens)
  sent_i = word_i = NULL ## used in data.table syntax, but need to have bindings for R CMD check


  ## check whether the columns specified in the arguments exist
  for(cname in c(doc_col, word_i_col, sent_i_col, meta_cols)){
    if (!cname %in% colnames(tokens)) stop(sprintf('"%s" is not an existing columnname in "tokens"', cname))
  }
  if (!is.null(meta)){
    if (!doc_col %in% colnames(meta)) stop(sprintf('"meta" does not contain the document id column (%s)', doc_col))
  }

  ## change column names, make doc_id factor (both in reference, for efficiency) and check whether the right types are used
  data.table::setnames(tokens, which(colnames(tokens) == doc_col), 'doc_id')
  tokens[,'doc_id' := fast_factor(tokens$doc_id)]
  if (!is.null(sent_i_col)) {
    data.table::setnames(tokens, which(colnames(tokens) == sent_i_col), 'sent_i')
    if (!methods::is(tokens$sent_i, 'numeric')) stop('sent_i_col has to be numeric/integer')
    if (!methods::is(tokens$sent_i, 'integer')) tokens[,sent_i := as.integer(sent_i)]
  }

  if (!is.null(word_i_col)) {
    data.table::setnames(tokens, which(colnames(tokens) == word_i_col), 'word_i')
    if (!methods::is(tokens$word_i, 'numeric')) stop('word_i_col has to be numeric/integer')
    if (!methods::is(tokens$word_i, 'integer')) tokens[,word_i := as.integer(word_i)]
  } else {
    warning('No word_i column specified. Word order used instead (see documentation).')
    tokens$word_i = 1:nrow(tokens)
    word_is_local = F
  }

  ## delete unused columns
  if (is.null(feature_cols)) feature_cols = colnames(tokens)[!colnames(tokens) %in% c(doc_col, sent_i_col, word_i_col, meta_cols)]
  used_columns = c('doc_id','sent_i','word_i', meta_cols, feature_cols)
  unused_columns = setdiff(colnames(tokens), used_columns)
  if(length(unused_columns) > 0) tokens[, (unused_columns) := NULL]

  for(fcol in feature_cols) {
    if (class(tokens[[fcol]]) %in% c('factor','character')) tokens[,(fcol) := fast_factor(tokens[[fcol]])]
  }

  ## set data.table keys (sorting the data) and verify that there are no duplicates
  if (!is.null(sent_i_col)) {
    data.table::setkeyv(tokens, c('doc_id','sent_i','word_i'))
    if (!anyDuplicated(tokens, by=c('doc_id','sent_i','word_i')) == 0) stop('tokens should not contain duplicate triples of documents (doc_col), sentences (sent_i_col) and word positions (word_i_col)')
  } else {
    data.table::setkeyv(tokens, c('doc_id','word_i'))
    if (!anyDuplicated(tokens, by=c('doc_id','word_i')) == 0) stop('tokens should not contain duplicate doubles of documents (doc_col) and word positions (word_i_col)')
  }

  ## make sure that sent_i and word_i are locally unique within documents
  ndoc = nrow(unique(tokens, by='doc_id'))
  if (!is.null(sent_i_col)){
    if (sent_is_local) {
        if (ndoc > 1) if (!anyDuplicated(unique(tokens, by=c('doc_id','sent_i')), by='sent_i') == 0) warning("Sentence positions (sent_i) do not appear to be locally unique within documents (no duplicates). Unless you are sure they are, set sent_is_local to FALSE (and read documentation)")
    }
    if (!sent_is_local) tokens[,'sent_i' := local_position(tokens$sent_i, tokens$doc_id, presorted = T)] ## make sure sentences are locally unique within documents (and not globally)
    if (!word_is_local) tokens[,'word_i' := global_position(tokens$word_i,
                                                            global_position(tokens$sent_i, tokens$doc_id, presorted = T, position_is_local=T),
                                                            presorted = T)]  ## make word positions globally unique, taking sentence id into account (in case words are locally unique within sentences)
  }
  if (word_is_local) {
    if (ndoc > 1) if (!anyDuplicated(tokens, by=c('doc_id','word_i')) == 0) warning("Word positions (word_i) do not appear to be locally unique within documents (no duplicates). Unless you are sure they are, set word_is_local to FALSE (and read documentation)")
  } else {
    tokens[,'word_i' := local_position(tokens$word_i, tokens$doc_id, presorted=T)] ## make words locally unique within documents
  }

  ## arrange the meta data
  if (!is.null(meta)) {
    meta = data.table::as.data.table(meta)
    data.table::setnames(meta, which(colnames(meta) == doc_col), 'doc_id')
    meta[,'doc_id' := as.character(meta$doc_id)]
    data.table::setkeyv(meta, 'doc_id')

    if (!all(levels(tokens$doc_id) %in% meta$doc_id)) warning('For some documents in tokens the meta data is missing')
    if (!all(meta$doc_id %in% levels(tokens$doc_id))) warning('For some documents in the meta data there are no tokens. These documents will not be included in the meta data')
    meta = meta[list(levels(tokens$doc_id)),]
  } else {
    meta = data.table::data.table(doc_id=as.character(levels(tokens$doc_id)), key='doc_id')
  }

  if (!is.null(meta_cols)){
    add_meta = unique(tokens[,c('doc_id', meta_cols), with=F])
    if (nrow(add_meta) > nrow(meta)) stop('The document meta columns specified in meta_cols are not unique within documents')
    meta = cbind(meta, add_meta[,meta_cols,with=F])
  }
  meta$doc_id = as.character(meta$doc_id) ## prevent factors, which are unnecessary here and can only lead to conflicting levels with the doc_id in data

  tCorpus$new(data=tokens, meta = meta)
}

## alternative:: add formal data check and correction methods, and then simply create the tcorpus from the data and then perform the checks and corrections

