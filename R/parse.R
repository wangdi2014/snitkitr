#' Remove variant matrix rows with bugs in the annotations
#' @description Removes rows from matrix in which row.names have bugs. Bugs include
#' row annotations with 1) warnings, 2) incorrect number of pipes (should be a
#' multiple of 9), 3) the string CHR_END (we want this to be the last gene in the
#' annotated genome instead of CHR_END), 4) no strand or locus tag information or 5) rows
#' annotated with "None". Eventually can get rid of this when all the bugs are fixed,
#' or can keep as a sanity check to make sure we aren't seeing these bugs in the
#' row annotation. You should run varmat_code and varmat_allele through this function separately
#' and should expect the same rows to be removed.
#'
#' @param varmat - data.frame where the rows are variants, the columns are genomes,
#' and the row.names are annotations
#'
#' @return returns a varmat (class = data.frame) with rows with bugs in the
#' annotation removed. Also writes a file called YEAR_MONTH_DATE_rows_removed_from_varmatNAME_due_to_bugs.txt
#' logging the row names of the removed rows.
#'
#' @export
#' @noRd
remove_rows_with_bugs <- function(varmat){
  library(magrittr)
  library(Biostrings)
  library(stringr)

  # Intialize a filename to log the removed rows
  filename = paste0(Sys.Date(), '_rows_removed_from_', deparse(substitute(varmat)), 'due_to_bugs.txt')

  # 1. Remove rows with warnings in the row annotation
  rows_with_warnings = grep('WARNING', row.names(varmat))
  write(row.names(varmat)[rows_with_warnings], file = filename, append = TRUE)
  if (length(rows_with_warnings) > 0) {
    varmat = varmat[-rows_with_warnings,]
  }

  # 2. Remove rows with the incorrect number of pipes in the row annotation
  # number of |
  num_pipes = str_count(row.names(varmat), '\\|')
  table(num_pipes) # remove not intervals of 9

  num_semicolon = str_count(row.names(varmat), ';')
  table(num_semicolon)

  write(row.names(varmat)[(num_pipes/(num_semicolon - 1)) %% 9 != 0], file = filename, append = TRUE)

  # only keep rows with correct number of pipes
  varmat = varmat[(num_pipes/(num_semicolon - 1)) %% 9 == 0,] # must be a multiple of 9

  # 3. Remove rows that still have 'CHR_END' in the row annotation
  rows_with_chr_end = grep('CHR_END', row.names(varmat))
  write(row.names(varmat)[rows_with_chr_end], file = filename, append = TRUE)

  if (length(rows_with_chr_end) > 0) {
    varmat = varmat[-rows_with_chr_end, ]
  }

  # 4. Remove rows with not enough locus tag information - have to wait for Ali
  # to convert all reported gene symbols to locus_tags
  # split_annotations <- strsplit(row.names(varmat), ";")
  # sapply(split_annotations, function(split){
  #   annot = split[1]
  #   locus_tag = gsub('^.+locus_tag=','',annot) %>% gsub(' Strand .*$','',.)
  # })

  #5. Remove rows with no strand information or locus tag information in the
  # row annotations
  locus_tag = unname(sapply(row.names(varmat), function(row){
    gsub('^.+locus_tag=', '', row) %>% gsub(' Strand .*$', '', .)
  }))
  no_locus_tag_listed = grep('NULL', locus_tag)

  no_strand_info_listed = grep('No Strand Information found', row.names(varmat))

  remove_bc_lack_of_info = union(no_locus_tag_listed, no_strand_info_listed)
  write(row.names(varmat)[remove_bc_lack_of_info], file = filename, append = TRUE)
  if (length(remove_bc_lack_of_info) > 0) {
    varmat = varmat[-remove_bc_lack_of_info, ]
  }

  #6. Remove rows with "None" annotation
  remove_bc_none_annotation = grep('None', row.names(varmat))
  write(row.names(varmat)[remove_bc_none_annotation], file = filename, append = TRUE)
  if (length(remove_bc_none_annotation) > 0) {
    varmat = varmat[-remove_bc_none_annotation, ]
  }
  return(varmat)
}

#' Remove rows with no variants or that are completely masked
#' @description Removes rows that have no variants (the same allele in every
#' sample +/- N and dash) or rows that are completely masked (all Ns).
#'
#' @param snpmat_code - data.frame where the rows are variants (numeric description
#' variants: numbers ranging from -4 to 3), the columns are genomes, and the
#' row.names are annotations
#' @param snpmat_allele - data.frame where the rows are variants (character description
#' variants: A,C,T,G,N,-), the columns are genomes, and the row.names are annotations
#'
#' @return Returns a list with the following elements (in order):
#' 1. snpmat_code (class = data.frame) with non-variant rows removed. All rows have at least
#' one sample with a variant.
#' 2. snpmat_allele (class = data.frame) with non-variant rows removed. All rows have at least
#' one sample with a variant.
#' 1 and 2 should be the same dimensions and have the same row names.
#' Also writes a file called YEAR_MONTH_DATE_rows_removed_because_no_variants
#' logging the row names of the removed rows.
#' @export
remove_rows_with_no_variants_or_completely_masked <- function(snpmat_code, snpmat_allele){
  rows_with_one_allele_or_all_Ns_or_dashes = apply(snpmat_allele, 1, function(row){
    length(unique(row)) == 1
  })

  file = paste0(Sys.Date(), '_rows_removed_because_no_variants')
  write(x = row.names(snpmat_code)[rows_with_one_allele_or_all_Ns_or_dashes], file = file)

  snpmat_code_rows_removed = snpmat_code[!rows_with_one_allele_or_all_Ns_or_dashes,]
  snpmat_allele_rows_removed = snpmat_allele[!rows_with_one_allele_or_all_Ns_or_dashes,]

  return(list(snpmat_code_rows_removed, snpmat_allele_rows_removed))
}

#' Split rows that have multiple annotations
#' @description Rows that have X number of annotations are replicated X number of times.
#' Multiple annotations can be due to 1) multiallelic sites which will result in an
#' annotation for each individual allele and 2) SNPs in overlapping genes which will result in
#' an annotation for each gene or 3) a combination of 1 and 2. The row names will be
#' changed to have one annotation per row (that is, multiallelic SNPs are represented
#' as biallelic sites and each snp in a gene that overlaps with another gene will
#' be represented on a single line). The contents of the data.frame is replicated --
#' that is, the contents of the replicated rows are NOT changed. You should run
#' snpmat_code and snpmat_allele through this function separately and should expect
#' the data.frames to have the same dimensions and same duplicated rows.
#'
#' @param snpmat - data.frame where the rows are variants, the columns are genomes,
#' and the row.names are annotations
#'
#' @return Returns a list with the following elements (in order):
#' 1. rows_with_multiple_annots_log - a logical vector with length of
#' nrow(snpmat_added) indicating which rows once had multiple annotations (that is,
#' were split from one row into multiple rows)
#' 2. rows_with_mult_var_allele_log -  a logical vector with length of
#' nrow(snpmat_added) indicating which rows once had multiple annotations in the
#' form of  multiallelic sites (that is, were split from multiallelic sites to
#' biallelic sites)
#' 3. rows_with_overlapping_genes_log -> -  a logical vector with length of
#' nrow(snpmat_added) indicating which rows once had multiple annotations in the
#' form of overlapping genes (that is, were split from a SNP in multiple genes
#' to each gene being represented on a single line)
#' 4. split_rows_flag - an integer vector indicating which rows were split from
#' from a row with multiple annotations (For example if snpmat had 4 rows: 1, 2, 3, 4
#' with row 2 having 3 annotations and row 4 having 2 annotations, the vector would
#' be 1 2 2 2 3 4 4).
#' 5. snpmat_added - a data.frame where the rows are variants, the columns are genomes,
#' and the row.names are SPLIT annotations (each overlapping gene and multiallelic site
#' represented as a single line).
#' @export
#'
split_rows_with_multiple_annots <- function(snpmat){

  num_dividers <- sapply(1:nrow(snpmat), function(x) lengths(regmatches(row.names(snpmat)[x], gregexpr(";[A,C,G,T]", row.names(snpmat)[x]))))

  rows_with_multiple_annotations <- c(1:nrow(snpmat))[num_dividers >= 1 & str_count(row.names(snpmat), '\\|') > 9]

  # Get rows with multallelic sites
  rows_with_multi_allelic_sites = grep('^.+> [A,C,T,G],[A,C,T,G]', row.names(snpmat))

  # Get SNVs present in overlapping genes
  split_annotations <- strsplit(row.names(snpmat)[rows_with_multiple_annotations], ";")

  num_genes_per_site = sapply(split_annotations, function(annots){
    unique(sapply(2:length(annots), function(i){
      unlist(str_split(annots[i], '[|]'))[4]
    }))
  })
  rows_with_overlapping_genes = rows_with_multiple_annotations[sapply(num_genes_per_site, length) > 1]

  # Duplicate rows with multiallelic sites
  row_indices = 1:nrow(snpmat)

  snpmat_added = snpmat[rep(row_indices, num_dividers),]

  # When rows are duplicated .1, .2, .3, etc are added to the end
  # (depending on how many times they were duplicated)
  # Remove to make the duplicated rows have the exact same name
  #names_of_rows = row.names(snpmat_added) %>% gsub(';\\.[0-9].*$', ';', .)

  split_rows_flag = rep(row_indices, num_dividers)

  dup = unique(split_rows_flag[duplicated(split_rows_flag)]) # rows that were duplicated

  split_annotations <- strsplit(row.names(snpmat_added)[split_rows_flag %in% dup], ";")

  # FIX ANNOTS OF SNP MAT ADDED - RELIES ON THE .1, .2, .3, ... etc flag
  row.names(snpmat_added)[split_rows_flag %in% dup] =  sapply(split_annotations, function(r){
    if (length(r) == 3) {
      paste(r[1], r[2], sep = ';')
    } else if (length(r) > 3 & length(str_split(r[length(r)], '')[[1]]) > 2) {
      paste(r[1], r[2], sep = ';')
    } else {
      index = as.numeric(gsub('\\.','',r[length(r)]))
      paste(r[1], r[index + 2], sep = ';')
    }
  })

  rows_with_multiple_annots_log = split_rows_flag %in% rows_with_multiple_annotations
  rows_with_mult_var_allele_log = split_rows_flag %in% rows_with_multi_allelic_sites
  rows_with_overlapping_genes_log = split_rows_flag %in% rows_with_overlapping_genes

  # FIX ANNOTS OF SNP MAT ADDED - ROWS WITH MULT VAR ALLELE
  row.names(snpmat_added)[rows_with_mult_var_allele_log] = sapply(row.names(snpmat_added)[rows_with_mult_var_allele_log], function(r){
    if (grepl('> [A,C,T,G],[A,C,T,G].*functional=', r)) {
      var =  gsub('^.*Strand Information:', '', r) %>% gsub('\\|.*$', '', .) %>% substr(.,nchar(.),nchar(.))
      gsub('> [A,C,T,G],[A,C,T,G].*functional=', paste('>', var, 'functional='), r)
    }
  })

  return(list(rows_with_multiple_annots_log,
              rows_with_mult_var_allele_log,
              rows_with_overlapping_genes_log,
              split_rows_flag,
              snpmat_added))
}
