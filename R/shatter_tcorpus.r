#' Shatter a tCorpus to create or append a shattered tCorpus
#'
#' Shatters a tCorpus into one or more shards (i.e. subsets). Each subset is saved on disk and removed from memory.
#' The returned shattered_tCorpus object links to these subsets, and can be used as a normal tCorpus object (though with some restrictions).
#' Where possible, the tCorpus functions will then be performed per shard, and the entire tCorpus does not have to be kept in memory.
#' Put simply: if you run into memory problems because you have too much data, you'll probably want to shatter it.
#'
#' See the documentation for \link{shattered_tCorpus} for a more detailed explanation of why you would ever want to shatter your tCorpus.
#'
#' !! please read the documentation for shard_path if you intend to save the shattered_tCorpus
#'
#' @param tc a tCorpus object
#' @param stc THe name of the shattered tCorpus
#' @param meta_columns Optionally, meta columns can be used to index the shards. For example, if the meta columns "medium" and "month" are given, then all shards are first indexed in folders per month per medium
#' @param if_exists What to do if the stc already exists? Default is "stop", to prevent accidental overwriting. "append" can be used to add the new shards to the existing shattered tCorpus, and "overwrite" can be used to delete the old shattered tCorpus.
#' @param if_duplicates In case that if_exists == "append", what to do if the new tCorpus has document ids that are already in the shattered tCorpus? Default is "stop". Alternatively, duplicate doc_ids can be skipped ("skip"), in case they are actually identical, or the name can be changed ("rename") in case only the name is duplicate
#' @param compress Use compression
#' @param verbose If TRUE, report progress
#' @param tokens_per_shard The number of tokens per shard. This is an approximation, since a tCorpus should not be broken within documents. Also, given the number of shards that is required, tokens will be evently distributed (for instance, if tokens_per_shard is 1,000,000, and there are 1,500,000 tokens, you'll get 2 tokens of 750,000 shards)
#'
#' @return a shattered_tCorpus object
#' @export
shatter_tcorpus <- function(tc, stc, meta_columns=NULL, tokens_per_shard=1000000, if_exists=c('stop','append','overwrite'), if_duplicates=c('stop','skip','rename'), compress=TRUE, verbose=F) {
  if_exists = match.arg(if_exists)
  if_duplicates = match.arg(if_duplicates)
  meta_columns = if (!is.null(meta_columns)) match.arg(meta_columns, tc$meta_names, several.ok = T) else c()

  if (methods::is(stc, 'character')) {
    if (!grepl('.tCorpus$', stc)) stc = paste(stc, 'tCorpus', sep='.')
    stc = shattered_tCorpus$new(path=stc)
  }

  if (file.exists(stc$path())){
    if (if_exists == 'stop') stop('A shattered tCorpus with this name already exists at this location. Either rename, or set if_exists to "overwrite" or "append"')
    if (if_exists == 'overwrite') {
      unlink(stc$path(), recursive = TRUE)
      if (verbose) message(sprintf('Overwritten %s', stc$path()))
    }
    if (if_exists == 'append') {
        index = stc$index()
        tc = manage_duplicates(tc, index, if_duplicates)
        if (tc$n == 0) return(stc)
        tc = fit_columns_to_index(tc, stc)
        tc = reindex_features(tc, stc)
    }
  }
  if (!file.exists(stc$path())){ ## not that this should not be the else statement for the previous if, because it needs to check again in case if_exists == "overwrite"
    dir.create(stc$path())
    index = NULL
  }

  shards_path = sprintf('%s/%s', stc$path(), 'shards')
  shard_index = shatter_loop(tc, meta_columns=meta_columns, tokens_per_shard=tokens_per_shard, save_path=shards_path, compress=compress, verbose=verbose)

  new_index = cbind(.PATH=gsub('shard_[0-9]+_T=.*', '', shard_index),
                    .SHARD=shard_index,
                    .N = ntokens_index(tc),
                    tc$meta)

  index = rbindlist(list(index, new_index))
  setkeyv(index, c('.PATH', '.SHARD'))
  stc$set_index(index)

  info = shard_index_info(stc, head(tc$data), head(tc$meta), meta_columns)
  stc$set_info(info)

  stc$set_feature_levels(feature_levels_list(tc))## note that for appending, the feature levels in tc have already been matched with the previous data, and thus contain all levels

  inspect_shard_index(stc)
  stc
}

manage_duplicates <- function(tc, index, if_duplicates){
  duplicate = tc$meta$doc_id %in% index$doc_id
  if (sum(duplicate) > 0){
    if (if_duplicates == 'stop') stop('DUPLICATES. The new tcorpus contains doc_ids that are already in the shattered_tCorpus. If you know why, you can use the if_duplicates parameter to "skip" the duplicates or automatically "rename" them')
    if (if_duplicates == 'skip') {
      cat('## Skipping ', sum(duplicate), ' duplicate(s)\n')
      evalhere_duplicate = duplicate
      tc = tc$subset(subset_meta = !evalhere_duplicate, copy=T)
    }
    if (if_duplicates == 'rename') {
      cat('## Renaming ', sum(duplicate), ' duplicate(s)\n')
      docnames = tc$meta$doc_id
      i = 0
      while(sum(duplicate) > 0){
        i = i + 1
        oldname = docnames[duplicate]
        newname = sprintf('%s_D%s', oldname, i)

        match_i = match(tc$get_meta('doc_id')[duplicate], levels(tc$get('doc_id')))

        tc$doc_id_levels[match_i] = newname

        duplicate = tc$get_meta('doc_id') %in% index$doc_id | duplicated(tc$get_meta('doc_id')) ## also check whether there are duplicates within tc after changing names (very unlikely, but still)
      }
    }
  }
  tc
}


shard_index_info <- function(stc, data_head, meta_head, shard_folders) {
  ushards = stc$shards(normalize = F)
  data_n = regmatches(ushards, gregexpr('(?<=_T=)[0-9]+', ushards, perl = T))
  meta_n = regmatches(ushards, gregexpr('(?<=_M=)[0-9]+', ushards, perl = T))
  data_n = sum(as.numeric(data_n))
  meta_n = sum(as.numeric(meta_n))
  shards_n = length(ushards)

  sent_info = if ('sent_i' %in% colnames(data_head)) ' and sentences' else ''
  list(n=data_n, n_meta=meta_n, n_shards=shards_n, data_head=data_head, meta_head=meta_head, sent_info=sent_info, shard_folders=shard_folders)
}

ntokens_index <- function(tc){
  data = tc$data
  freq = data[,.N,by='doc_id']
  meta_id = tc$meta$doc_id
  freq$N[match(meta_id, freq$doc_id)]
}

fit_columns_to_index <- function(tc, stc){
  info = stc$info()
  name = stc$path()

  cnames = tc$names
  meta_cnames = tc$meta_names
  cnames_index = colnames(info$data_head)
  meta_cnames_index = colnames(info$meta_head)

  if (!identical(cnames, cnames_index)){
    missing_data = cnames_index[!cnames_index %in% cnames]
    if (length(missing_data) > 0) stop(sprintf('Cannot append. the following columns in %s are not in the new batch: %s', name, paste(missing_data, collapse=', ')))
    extra_data = cnames[!cnames %in% cnames_index]
    if (length(extra_data) > 0) warning(sprintf('New batch contains columns that are not in %s [%s]. These columns have not been added', name, paste(extra_data, collapse=', ')))
    delete_columns = setdiff(tc$names, cnames)
    tc$delete_columns(delete_columns, copy = F)
  }
  if (!identical(meta_cnames, meta_cnames_index)){
    missing_meta = meta_cnames_index[!meta_cnames_index %in% meta_cnames]
    if (length(missing_meta) > 0) stop(sprintf('Cannot append. the following META columns in %s are not in the new batch: %s', name, paste(missing_meta, collapse=', ')))
    extra_meta = meta_cnames[!meta_cnames %in% meta_cnames_index]
    if (length(extra_meta) > 0) warning(sprintf('New batch contains META columns that are not in %s [%s]. These columns have not been added', name, paste(extra_meta, collapse=', ')))
    delete_columns = setdiff(tc$meta_names, meta_cnames)
    tc$delete_meta_columns(delete_columns, copy = F)
  }
  tc$set_keys()
  tc
}


## manage factors

feature_levels_list <- function(tc){
  d = tc$data
  factors = colnames(d)[lapply(d, class) == 'factor']
  feature_levels = list()
  for(f in factors) feature_levels[[f]] = levels(d[[f]])
  feature_levels
}

reindex_features <- function(tc, stc){
  feature_levels = stc$feature_levels()
  features = tc$feature_names
  for(evalhere_feature in features){
    if (!methods::is(tc$get(evalhere_feature), 'factor')) {
      if (evalhere_feature %in% names(feature_levels)) {
        tc$set(evalhere_feature, as.factor(tc$get(evalhere_feature)), copy=F)
      } else next
    }
    fl = feature_levels[[evalhere_feature]]
    tc$set(evalhere_feature, match_factor_labels(tc$get(evalhere_feature), fl), copy=F)
  }
  tc$set_keys()
  tc
}

match_factor_labels <- function(f, flabels){
  ## change the integers of f (factor) to match the flabels, and append flabels to include the labels of f that are not in flabels. (by appending, the factor from which the flabels come does not have to change)
  add_labels = levels(f)[!levels(f) %in% flabels]
  flabels = c(flabels, add_labels)
  level_conversion = match(levels(f), flabels)
  factor(level_conversion[as.numeric(f)], levels=1:length(flabels), labels=flabels)
}

shatter_loop <- function(tc, meta_columns=c(), tokens_per_shard=1000000, n_shards=NA, save_path='', compress=TRUE, verbose=F, shard_index=rep(NA, tc$n_meta), verbose_string='') {
  if (!dir.exists(save_path)) dir.create(save_path)

  if (length(meta_columns) == 0){
    shard_index = save_shards(tc, tokens_per_shard=tokens_per_shard, n_shards=n_shards, save_path=save_path, compress=compress, verbose=verbose, verbose_string=verbose_string)
  } else {
    column = meta_columns[1]
    next_columns = meta_columns[!meta_columns == column]
    if (verbose) cat(verbose_string, column, '\n')
    verbose_string = paste(verbose_string, '---', sep='')

    val = as.character(tc$get_meta(column))
    for(uval in unique(val)){
      if (verbose) cat(verbose_string, uval, '\n')
      uval_path = if (save_path=='') uval else paste(save_path, uval, sep='/')
      if (!dir.exists(uval_path)) dir.create(uval_path)

      evalhere_i = which(val == uval)
      shard_index[evalhere_i] = shatter_loop(tc$subset(subset_meta=evalhere_i, copy = T), next_columns,
                                    tokens_per_shard=tokens_per_shard, n_shards=n_shards, save_path=uval_path, compress=compress,
                                    verbose_string=paste(verbose_string,'---', sep=''))
    }
  }
  shard_index
}


save_shards <- function(tc, tokens_per_shard=1000000, n_shards=NA, save_path='', compress=TRUE, verbose=F, verbose_string){
  existing_shards = list.files(save_path)
  n_existing_shards = sum(grepl('shard_[0-9]+_T=', existing_shards))

  n = tc$n_meta
  if (is.na(n_shards)) n_shards = ceiling(tc$n / tokens_per_shard)
  batch_i = data_batch(tc, 'document', n.batches=n_shards, for_meta = T)

  shard_index = rep(NA, n) ## using the original n, before deleting duplicates. Then use !duplicates to only provide the index for the non-duplicate indices
  if (is.null(batch_i)) return(shard_index) ## if there are no batches, stop

  for(i in 1:nrow(batch_i)){
    evalhere_meta_i = (batch_i$start[i]):(batch_i$end[i])
    shard = tc$subset(subset_meta = evalhere_meta_i, copy=T)
    shard$set_keys()
    if (shard$n_meta > 0){
      fname = sprintf('shard_%s_T=%s_M=%s.rds', i+n_existing_shards, shard$n, shard$n_meta)
      if (verbose) cat(verbose_string, fname, '\n')
      fpath = sprintf('%s/%s', save_path, fname)
      shard_index[evalhere_meta_i] = fpath
      saveRDS(shard, fpath, compress=compress)
    }
  }
  shard_index
}

equal_groups <- function(index, tokens_per_shard){
  n = sum(index$.N)
  n_shards = ceiling(n / (tokens_per_shard)) ## how many shards are required
  tokens_per_shard = ceiling(n / n_shards) ## what is the most equal distriution over those shards

  mod = cumsum(index$.N) %% tokens_per_shard
  break_i = mod < c(1, mod[-length(mod)]) # wrap around point
  shards = cumsum(break_i)+1

  ## if last shard is small (can happen if due to differences in document length the last few documents are just behind the wrapping point), distribute the documents over the other groups
  shardn = tapply(mod, shards, 'sum')
  if (shardn[length(shardn)] < tokens_per_shard*0.25) {
    is_last = shards == length(shardn)
    shards[is_last] = rep(1:(length(shardn)-1), length.out=sum(is_last))
  }
  match(shards, unique(shards))
}

collect_shards <- function(shard_names, select_doc_ids=NULL) {
  doc_id = NULL ## used in subset syntax, but needs to have bindings for R CMD check
  shard = merge_shards(sapply(shard_names, readRDS))
  evalhere_select_doc_ids = select_doc_ids
  if (!is.null(select_doc_ids)) shard = shard$subset(subset_meta = doc_id %in% as.character(evalhere_select_doc_ids), copy=T)
  shard
}

#' Redistribute shards in a shattered tCorpus
#'
#' For good performance it's generally best to keep shards of moderate size. Not too small to prevent tedious merging and looping, and not too big to prevent memory problems. This function redistributes the shards (within categories) to approximate the specified tokens_per_shard
#'
#' @param stc A shattered_tCorpus object
#' @param tokens_per_shard The number of tokens per shard. This is an approximation, since a tCorpus should not be broken within documents. Also, given the number of shards that is required, tokens will be evently distributed (for instance, if tokens_per_shard is 1,000,000, and there are 1,500,000 tokens, you'll get 2 tokens of 750,000 shards)
#'
#' @export
redistribute_shards <- function(stc, tokens_per_shard=100000) {
  shard_index = stc$index()
  shard_index$.I  = 1:nrow(shard_index) ## keep order to replace .SHARD and return the shard_index (instead of rbinding it)
  new_shard_index = rep(NA, nrow(shard_index))
  old_shard_files = c()
  new_shard_files = c()

  verbose = verbose_sum_counter(n=stc$info('n'))
  for(path in unique(shard_index$.PATH)){
    index = shard_index[path]
    newshards = equal_groups(index, tokens_per_shard)
    for(shard_i in unique(newshards)){
      i = shard_i == newshards
      shard = collect_shards(unique(index$.SHARD[i]), select_doc_ids = index$doc_id[i])
      shard_name = sprintf('shard_%s_T=%s_M=%s.rds', shard_i, shard$n, shard$n_meta)
      verbose(shard$n)

      new_shard_file = sprintf('%s/NEW_%s', path, shard_name)
      new_shard_files = union(new_shard_files, new_shard_file)
      saveRDS(shard, new_shard_file) ## add NEW_ to name -> delete old shards -> delete random string from new name
      new_shard_index[index$.I][i] = sprintf('%s/%s', path, shard_name)
    }
    old_shard_files = union(old_shard_files, unique(index$.SHARD))
  }

  ## remove old shards, rename new shards and renew the shard_index and info
  ## (do this only as the last step, so that if stuff crashes, the old shards and index stay intact. TODO: some other function (refresh_index?) should check for and delete lingering NEW_ files)
  removed = file.remove(old_shard_files)
  for(ns in new_shard_files) file.rename(ns, gsub('NEW_(shard_[0-9]+_T=)', '\\1', ns))

  shard_index$.I = NULL
  shard_index$.SHARD = new_shard_index
  setkeyv(shard_index, c('.PATH','.SHARD'))
  saveRDS(shard_index, sprintf('%s/index.rds', stc$path()))

  info = stc$info()
  info$n_shards = length(unique(shard_index$.SHARD))
  saveRDS(info, sprintf('%s/info.rds', stc$path()))

  inspect_shard_index(stc)
  stc
}


#' Change the way in which
#'
#' Note that depending on the size of the shattered_tCorpus this can take quite a while.
#'
#' @param stc A shattered_tCorpus object
#' @param new_stc Either a shattered_tCorpus object or a character string giving the name (or path) for a new shattered_tCorpus.
#' @param tokens_per_shard The number of tokens per shard. This is an approximation, since a tCorpus should not be broken within documents. Also, given the number of shards that is required, tokens will be evently distributed (for instance, if tokens_per_shard is 1,000,000, and there are 1,500,000 tokens, you'll get 2 tokens of 750,000 shards)
#' @param meta_columns The new column in the metadata used to index the shards
#' @param compress Use compression
#'
#' @export
reindex_shards <- function(stc, new_stc=stc, meta_columns=NULL, tokens_per_shard=1000000, compress=TRUE){
  if (!is.null(meta_columns)){
    mcols = colnames(stc$info()$meta_head)
    meta_columns = match.arg(meta_columns, mcols, several.ok = T)
  } else meta_columns = c()

  shards = stc$shards()

  if (methods::is(new_stc, 'character')) {
    if (!grepl('.tCorpus$', new_stc)) new_stc = paste(new_stc, 'tCorpus', sep='.')
    new_stc = shattered_tCorpus$new(path=new_stc)
  }

  path_is_same = stc$path(normalize=TRUE) == stc$path(normalize=TRUE)
  path_exists = file.exists(new_stc$path(normalize=TRUE))
  if (!path_is_same & path_exists) stop(sprintf("The path in new_stc (%s) already exists, and is not the same path as the given stc (in which case it will be overwritten). Solve by a) using a different new_stc, b) overwriting the old stc (by also passing the stc to new_stc) or c) deleting the path in new_stc", new_stc$path()))

  tmp_path = sprintf('%s_INCOMPLETE%s', new_stc$path(), sample(1:10000000, 1))
  verbose = verbose_sum_counter(n=stc$info('n'))
  for(shard in shards){
    tc = readRDS(shard)
    verbose(tc$n)
    new_stc = shatter_tcorpus(tc, stc = tmp_path, if_exists = 'append', meta_columns=meta_columns, tokens_per_shard = tokens_per_shard, compress=compress)
  }

  if (path_is_same) {
    ## if the new path is the same as the old path, remove the old path
    unlink(stc$path(), recursive = TRUE)
  }
  file.rename(tmp_path, new_stc$path())

  stc$set_info('')
  stc$info()

  new_stc
}



###### debugging and cleanup #######
## if code is interrupted there can be lingering shards in the .tCorpus folder that are not in the index
## these shards are ignored and do no harm, but it is good manners to delete them
## also, for debugging it's nice to detect when stuff goes wrong here.

inspect_shard_index <- function(stc){
  index_shards = stc$shards(normalize = T)
  existing_shards = list.files(sprintf('%s/shards', stc$path()), recursive = T, full.names = T)
  existing_shards = normalizePath(existing_shards)

  missing = setdiff(index_shards, existing_shards)
  unindexed = setdiff(existing_shards, index_shards)

  if (length(missing > 0)) stop(sprintf('MISSING SHARDS. %s out of %s of the shard files in the index do not exist. Unless you have been working behind the scenes within the slots and/or shard files (not judging, just saying), this is a bug (and should kindly be reported as such)', length(missing), length(index_shards)))
  if (length(unindexed > 0)) {
    warning(sprintf('DELETED LINGERING SHARDS. There were %s files within the shards folder (%s/shards) that are not in the index (probably due to interupted code in creating or changing the tCorpus). These have been deleted', length(unindexed), stc$path()))
    file.remove(unindexed)
  }
}
