##' Join lines of text recursively
##' 
##' @param lines A character vector
##' @param extract_pat A regular expression extracting parts of the
##' character strings to join (defaults to \code{.*})
##' @param break_pat A regular expression that sets a break condition.
##' The line where this pattern matches is the last to be joined. 
##' If not set, all lines will be joined
##' @param sep if \code{FALSE} the joined lines are concatenated without
##' intervening spaces 
##' 
##' @return A list with two elements. The first contains the joined
##' character vector, the second the number of lines joined
##' @keywords internal
joinLines <- function (lines, extract_pat=".*", break_pat=NULL, sep=TRUE) {
  i  <-  0
  list(eval(function (lines, extract_pat, break_pat) {
    l <- regmatches(lines[1], regexpr(extract_pat, lines[1], perl=T))
    i <<- i + 1
    
    if (length(l) == 0) {
      # jump out if we reach the last element of the character vector
      i <<- i - 1
      return(l) }
    else if (!is.null(break_pat) && grepl(break_pat, l, perl=TRUE))
      # or if a break pattern is set jump out when the break condition is met 
      return(l)
    
    if (sep)
      l <- paste(l, Recall(lines[-1], extract_pat, break_pat))
    else
      l <- paste0(l, Recall(lines[-1], extract_pat, break_pat))
  }) (lines, extract_pat=extract_pat, break_pat=break_pat), i)
}

##' Format paragraphs
##' 
##' Similar to \code{\link{strwrap}} but returns a single string with
##' linefeeds inserted
##' 
##' @param s a character vector or a list of character vectors
##' @param width a positive integer giving the column for inserting
##' linefeeds
##' @param indent an integer giving the indentation of the first line of
##' the paragraph; negative values of \code{indent} are allowed and reduce
##' the width for the first line by that value.
##' @param offset a non-negative integer giving the indentation of all
##' but the first line
##' @param split regular expression used for splitting. Defaults to
##' a whitespace character.
##' @param FORCE if \code{TRUE} words are force split if the available with
##' is too small
##' 
##' @return a character vector
##' @keywords internal
linebreak <- function (s, width=getOption("width") - 2, indent=0, offset=0,
                       split=" ", FORCE=FALSE) {
  if (!is.character(s)) 
    s <- as.character(s)
  
  if (length(s) == 0L)
    return("")
  
  # set indent string to "" if a negative value is given
  # this lets us shrink the available width for the first line by that value
  indent_string <- blanks(ifelse(indent < 0, 0, indent))
  offset_string <- paste0("\n", blanks(offset))

  s <- mapply(function (s, width, offset, indent, indent_string, split, FORCE) {
    # remove leading and trailing blanks
    # convert newlines, tabs, spaces to " "
    # find first position where 'split' applies
    s <- gsub("[[:space:]]+", " ", gsub("^[[:blank:]]+|[[:blank:]]+$", "", s), perl=TRUE)
    fws <- regexpr(split, s, perl=TRUE)
    if (offset + indent + nchar(s) > width) {
      # if not everything fits on one line
      if ((fws == -1 || fws >= (width - offset - indent)) && FORCE) {
        # if no whitespace or first word too long and force break
        # cut through the middle of a word
        pat1 <- paste0("^.{", width - offset - indent, "}(?=.+)")
        pat2 <- paste0("(?<=^.{", width - offset - indent, "}).+")
        leading_string <- regmatches(s, regexpr(pat1, s, perl=TRUE))
        trailing_string <- regmatches(s, regexpr(pat2, s, perl=TRUE)) 
        s <- paste0(indent_string, leading_string, offset_string,
                   linebreak(s=trailing_string, width=width, indent=0,
                             offset=offset, split=split, FORCE=FORCE))
      } 
      else if ((fws == -1 || fws >= (width - offset + indent)) && !FORCE) {
        # if no whitespace or first word too long and NO force break
        # stop right here
        stop("Can't break in the middle of a word. Use the force!")
      }
      else {
        # break the line
        s_split <- unlist(strsplit(s, split))
        s_cum <- cumsum(nchar(s_split) + 1)
        leading_string <- 
          paste0(s_split[s_cum < width - offset - indent],
                 ifelse(split == " ", "", split), collapse=split)
        trailing_string <- 
          paste0(s_split[s_cum >= width - offset - indent], collapse=split)
        s <- paste0(indent_string, leading_string, offset_string,
                   linebreak(s=trailing_string, width=width, indent=0,
                             offset=offset, split=split, FORCE=FORCE))
      }
    }
    else
      # if everything fits on one line go with the string
      s
  }, s, width, offset, abs(indent), indent_string, split, FORCE, 
                SIMPLIFY=FALSE, USE.NAMES=FALSE)
    unlist(s)
}

##' create blank strings with a given number of characters
##' @seealso Examples for \code{\link{regmatches}}
##' @keywords internal
blanks <- function(n) {
  vapply(Map(rep.int, rep.int(" ", length(n)), n, USE.NAMES=FALSE),
         paste, "", collapse="")
}

##' Extract matched group(s) from a string.
##'
##' @param pattern character string containing a regular expression
##' @param str character vector where matches are sought
##' @param capture if \code{TRUE} capture groups are returned in addition
##' to the complete match
##' @param perl if \code{TRUE} perl-compatible regexps are used.
##' @param global if \code{TRUE} \code{gregexpr} is used for matching
##' otherwise \code{regexpr}.
##' @param ignore.case case sensitive matching
##' @return a list containing a \code{match} and a \code{capture} component
##' @keywords character
##' @keywords internal
##' @examples
##' ##
strmatch <- function (pattern, str, capture=TRUE, perl=TRUE, global=TRUE, ignore.case=FALSE) {
  
  if (!is.atomic(str))
    stop("String must be an atomic vector", call. = FALSE)
  
  if (!is.character(str)) 
    string <- as.character(str)
  
  if (!is.character(pattern)) 
    stop("Pattern must be a character vector", call. = FALSE)
  
  if (global)
    m <- gregexpr(pattern, str, perl=perl, ignore.case=ignore.case)
  else
    m <- regexpr(pattern, str, perl=perl, ignore.case=ignore.case)
  
  .matcher <- function (str, m) {
    Map( function (str, start, len) substring(str, start, start + len - 1L), 
         str, m, lapply(m, attr, "match.length"), USE.NAMES=FALSE)
  }
  
  match <- if (capture) {
    .capture.matcher <- function (str, m) {
      cap <- Map( function (str, start, len) {
        mapply( function (str, start, len) {
          substr(str, start, start + len - 1L) 
        }, str, start, len, USE.NAMES=FALSE)
      }, str, lapply(m, attr, "capture.start"),
                  lapply(m, attr, "capture.length"), USE.NAMES=FALSE)
      
      cap_names <- lapply(m, attr, "capture.names")
      if (all(nchar(cap_names) > 0)) {
        if (!all(mapply(function (c, n) length(c) == length(n), cap, cap_names)))
          warning("Mismatch between number of captures and capture names", call.=TRUE)
        
        cap <- mapply( function (val, name) `names<-`(val, name),
                       cap, cap_names, USE.NAMES=FALSE)
      }
      
      cap
    }
    
    list(match=.matcher(str, m),
         capture=if (!is.null(attributes(m[[1]])$capture.start))
           .capture.matcher(str, m) else NULL)
  } else {
    match <- .matcher(str, m)
  }
  match
}

.typeToFeature <- function (s) {
  s <- gsub("gene_component_region", "misc_feature", s)
  s
}

# substitute gff-specific attribute tags for GenBank qualifiers
.tagToQualifier <- function (s) {
  s <- sub("^ID$", "locus_tag", s)
  s <- sub("^Name$", "gene", s)
  s <- sub("^Dbxref$", "db_xref", s)
  s <- tolower(s)
  s <- sub("^", "/", s)
  s
}

## TAB - %09, NL - %0A, CR - %0D, 
## %3B (semicolon), %3D (equals),
## %25 (percent), %26 (ampersand)
## %2C (comma)
.unescape <- function (s) {
  s <- gsub("%3B", ";", s)
  s <- gsub("%3D", "=", s)
  s <- gsub("%25", "%", s)
  s <- gsub("%26", "&", s)
  s <- gsub("%2C", ",", s)
  s <- gsub("^", "\"", s)
  s <- gsub("$", "\"", s)
  s
}

.cleanQualifiers <- function (q, v) {
  # introduce line breaks after 80 cols
  # the negative indent accounts for the length of the qualifier tag
  # and the following "="
  v <- linebreak(s=.unescape(v), width=79, offset=21,
                 indent=-(nchar(q)+1), FORCE=TRUE)
  l_pos <- which(pmatch(q, "/locus_tag", dup=TRUE, nomatch=0) == 1)
  p_pos <- which(pmatch(q, "/parent", dup=TRUE, nomatch=0) == 1)
  g_pos <- which(pmatch(q, "/gene", dup=TRUE, nomatch=0) == 1)
  l_val <- v[l_pos]
  p_val <- v[p_pos]
  g_val <- v[g_pos]
  lp <- c(l_val, p_val)
  lpg <- c(l_val, p_val, g_val)
  
  if (length(g_val) != 0 && 
    !any(grepl(pattern=g_val, x=c(l_val, p_val)))) {
    # if gene exists and is different from locus tag
    # retain gene and choose locus tag among parent and locus tag
    # and throw out parent
    v[l_pos] <- lp[which(nchar(lp) == min(nchar(lp)))]
    v <- v[-c(l_pos[-1], p_pos)]
    q <- q[-c(l_pos[-1], p_pos)]
  } 
  else {
    # otherwise choose among locus tag, parent, and gene; throw
    # out parrent and gene
    v[l_pos] <- lpg[which(nchar(lpg) == min(nchar(lpg)))]
    v <- v[if (length(s <- c(l_pos[-1], p_pos, g_pos)) > 0) -s else TRUE]
    q <- q[if (length(s <- c(l_pos[-1], p_pos, g_pos)) > 0) -s else TRUE]
  }
  if (length(v) > 0) 
    return(list(q=q, v=v))
  else
    invisible(NULL)
}

# --R-- vim:ft=r:sw=2:sts=2:ts=4:tw=76:
#       vim:fdm=marker:fmr={{{,}}}:fdl=0
