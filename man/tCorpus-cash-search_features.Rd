% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/documentation_methods.r
\name{tCorpus$search_features}
\alias{search_features.tCorpus}
\alias{tCorpus$search_features}
\title{Find tokens using a Lucene-like search query}
\arguments{
\item{keyword}{The keyword part of the query, see explanation in query_tutorial markdown or in details below}

\item{condition}{The condition part of the query, see explanation in query_tutorial markdown or in details below}

\item{code}{The code given to the tokens that match the query (usefull when looking for multiple queries)}

\item{queries}{Alternatively, a data.frame can be given that contains a "keyword" column, and optionally columns for the "condition", "code" and "condition_once" paramters.}

\item{feature}{The name of the feature column within which to search.}

\item{condition_once}{logical. If TRUE, then if an keyword satisfies its conditions once in an article, all keywords within that article are coded.}

\item{subset_tokens}{A call (or character string of a call) as one would normally pass to subset.tCorpus. If given, the keyword has to occur within the subset. This is for instance usefull to only look in named entity POS tags when searching for people or organization. Note that the condition does not have to occur within the subset.}

\item{subset_meta}{A call (or character string of a call) as one would normally pass to the subset_meta parameter of subset.tCorpus. If given, the keyword has to occur within the subset documents. This is for instance usefull to make queries date dependent. For example, in a longitudinal analysis of politicians, it is often required to take changing functions and/or party affiliations into account. This can be accomplished by using subset_meta = "date > xxx & date < xxx" (given that the appropriate date column exists in the meta data).}

\item{keep_false_condition}{if True, the keyword hits for which the condition was not satisfied are also returned, with an additional column that indicates whether the condition was satisfied. This can be used to investigate whether the condition is too strict, causing false negatives}

\item{only_last_mword}{If TRUE, then if multiword keywords are used (i.e. using double quotes, for instance "the united states"), only return the index of the last word. Note that if this is set to FALSE, it affects the occurence frequency, which is often a bad idea (e.g., counting search hits, word co-occurence analysis)}

\item{verbose}{If TRUE, progress messages will be printed}
}
\description{
Search tokens in a tokenlist using a query that consists of an keyword, and optionally a condition. For a detailed explanation of the query language please consult the query_tutorial markdown file. For a quick summary see the details below.

Note that the query arguments (keyword, condition, code, condition_once) can be vectors to search multiple queries at once. Alternatively, the queries argument can be used to pass these arguments in a data.frame
}
\details{
Brief summary of the query language

The keyword:
\itemize{
   \item{is the actual feature that has to be found in the token}
   \item{can contain multiple words with OR statement (and empty spaces are also considered OR statements)}
   \item{can contain multiword strings, using quotes. e.g. "united states"}
   \item{can contain word proximities, using quotes plus tilde and a number specifiying the word distance. e.g. "climate chang*"~10}
   \item{accepts the ? wildcard, which means that any single character can be used in this place}
   \item{accepts the * wildcard, which means that any number of characters can be used in this place}
   \item{is be default not case sensitive, but can be made so by adding ~s. e.g. COP~s}
 }

The condition:
\itemize{
   \item{has to be TRUE for the keyword to be accepted. Thus, if a condition is given, the query can be interpreted as: keyword AND condition}
   \item{works identical to the keyword, but with several additional options:}
   \item{- can also contain complex boolean statements, using AND, OR and NOT statements, and using parentheses}
   \item{- can be specified for a maximum word distance of the keyword using the ^ (caret) symbol, where "word^50" means that "word" is looked up within 50 words of the keyword. This can also be used after multiword strings, and in combination with the tilde. e.g. "climate chang*"~5^10 will check if the words climate and change/changing/etc. co-occur within 5 words, and if so, at least on word should occur within 10 words of the keyword}
   \item{- the case sensitive and word distance flags can be used together. e.g. COP~s^50 means that all capital COP must be found within 50 words of the keyword}
}

Parameters:
\itemize{
   \item{condition_once -> if TRUE, then if the condition is satisfied at least once in an article, all occurences of the keyword are accepted. }
}
}
\section{Usage}{

## R6 method for class tCorpus. Use as tc$method (where tc is a tCorpus object).

\preformatted{
search_features(keyword = NA, condition = NA, code = NA,
                queries = NULL, feature = 'word', condition_once=F,
                subset_tokens = NA, subset_meta = NA,
                keep_false_condition = F, only_last_mword = F, verbose = F)
             }
}

