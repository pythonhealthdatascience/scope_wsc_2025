# Analysis of final set

library(tidyverse)
library(stringi)
library(data.table)

# 1. Clean dataset, clean authors, save as file 6
# Read in file 5: following full text read and data extraction

fullset <- read.csv("datasets/5_fullset_analysis.csv") %>% 
  filter(ACCEPT == 1) %>% 
  select(-reason)

################################################################################

# Prepare data for DES and hybrid counts per year
line_data <- fullset %>%
  group_by(year) %>%
  summarise(
    DES_count = sum(DES, na.rm = TRUE),
    hybrid_count = sum(hybrid, na.rm = TRUE)
  )


###################################
# Extend authors - exploratory investigation of author relationships

fullset$authors_clean <- fullset$authors %>%
  # Replace special characters (e.g., accented letters) with ASCII equivalents
  stri_trans_general("Latin-ASCII") %>%
  # Split authors by ";" to separate individual authors
  str_split(";") %>%
  # For each author list, extract surnames (the first token before the first comma or space)
  map_chr(~paste(trimws(sapply(.x, function(author) {
    # Remove leading/trailing whitespace
    author <- trimws(author)
    # Extract surname (before comma or first whitespace)
    surname <- str_split(author, ",|\\s")[[1]][1]
    return(surname)
  })), collapse = "; "))

# View cleaned results
fullset %>% select(authors, authors_clean) %>% head()

write.csv(fullset, "datasets/6_fullset_authors.csv")

##################################################################

# Manual update of authors list on file 6 checking for errors 
# and save as file 7

##################################################################

# read in file 7

fullset <- read.csv("datasets/7_fullset_authors.csv")

# count authors
top_authors <- fullset %>%
  mutate(authors_clean = strsplit(as.character(authors_clean), "; ")) %>% # Ensure authors_clean is a character vector
  unnest(authors_clean) # Expand list into rows

top_authors <- top_authors %>%
  count(authors_clean) %>% 
  filter(n>1)

###############################################################

