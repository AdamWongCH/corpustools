#' A shattered tCorpus class
#'
#' This documentation page discusses why you might want to use a shattered tCorpus. For actual usage, please consult the general documentation for the tCorpus class. The shattered tCorpus can be used in the same way, though certain features/methods might not be available (which features do work is marked in the documentation). To create a shattered tCorpus, see the \link{shatter_tcorpus} function.
#'
#' The idea behind the shattered tCorpus is that a large tCorpus can be divided into shards (i.e. subsets). Each shard is saved on disk instead of being kept in memory, and will only be loaded into memory when an action is required.
#' The shattered_tCorpus object links to these subsets, and can be used as a normal tCorpus object (though with some restrictions).
#' Where possible, the tCorpus functions will then be performed per shard, and the entire tCorpus does not have to be kept in memory.
#' Put simply: if you run into memory problems because you have too much data, you'll probably want to shatter it.
#'
#' If you like analogies, think of your huge corpus of texts as a huge vase.
#' You want to study the patterns on the vase, for obvious reasons, but the darn thing is too big to fit into your special vase pattern scanning maching.
#' Buying a bigger machine is out of your research budget and/or goals in life, so instead you decide to bring the hammer to it.
#' Now, each shard does fit into your machine, and you (and your army of reasearch assistants) can scan each piece separately and put the results back together.
#' However, you now have new problems.
#' One is that organizing this ordeal can be tricky: you don't want to lose track of any shards, and putting the results back together is often not trivial.
#' Another problem is that for some analyses you might also want to take certain characteristics of the whole vase into account, such as its shape.
#' Ideally, you want to study the whole vase, and let the tedious but necessary shattering and glueing be done for you, behind the scenes.
#' Back to our case: the shattered_tCorpus is a single object that can be treated as a normal tCorpus (with some restrictions), but behind the scenes it shatters the corpus so that it only has to keep one or several shards in memory at a time.
#'
#' So, to summarize.
#' Why do you want to shatter your corpus?
#' \itemize{
#' \item You don't. You simply have to because your data is too big for your machine. You hate this and want to think about it as little as possible.
#' }
#'
#' Why do I want to make a shattered_tCorpus. Why not simply loop over my data?
#' \itemize{
#' \item Firstly, because this can be a hassle. It's convenient to be able to work with your data through a single object. This also makes it easier to develop and share code for all sorts of analysis of big textual corpora.
#' \item Secondly, because certain operations become quite more complex to perform (efficiently), especially if they require both local information (shards) and global information (corpus).
#' }
#'
#' Can I big data now?
#' \itemize{
#' \item This functionality is not competing with big data software such as Hadoop. The goal is also not to facilitate cluster computing of shards. Still, if you have a decent computer and super-speed is not your goal, then the shattered_tCorpus approach should enable you to scale up pretty well.
#' }
#' @name shattered_tCorpus
NULL
