# read in files
library(tidyverse)
library(stringr) # if fuzzy matching required for dedup
library(stringdist) # a/a

wos <- read.csv("datasets/1_WOS.csv")
scopus <- read.csv("datasets/1_scopus.csv")

# Select columns 
wos <- wos %>% select(, c(2,9,10,14,23,48,58,59)) %>% 
  rename(authors = Authors,
         title = "Article.Title",
         source = "Source.Title",
         document = "Document.Type",
         DOI = DOI,
         link = "DOI.Link",
         year = "Publication.Year"
  ) %>% 
  mutate(DOI = tolower(DOI))

scopus <- scopus %>% 
  select(, c(1,4,5,6,14,15,17,20)) %>% 
  rename(authors = Authors,
         title = Title,
         source = "Source.title",
         document = "Document.Type",
         DOI = DOI,
         link = Link,
         year = Year
  ) %>% 
  mutate(DOI = tolower(DOI))

# bind records and fill NAs in DOI with unique dummy
all_records <- rbind(wos, scopus) %>%
  mutate(
    DOI = {
      is_empty <- (DOI == "" | is.na(DOI))
      dummy_index <- cumsum(is_empty)
      if_else(is_empty, paste0("dummy_", dummy_index), DOI)
    }
  )

# remove dups on DOI
all_records <- all_records %>% 
  distinct(DOI, .keep_all = TRUE)

all_records <- all_records %>% 
  filter(S1accept == 1) %>% 
  select(-S1accept)

write.csv(all_records, "datasets/2_SCOPUS_WoS_records.csv") 

# spidercite returned forward-backward citations. Filtered by title/abstract

spidercite <- read.csv("datasets/3_snowball_SCOPE.csv")

# select columns, lowercase DOI, dummy for na
spidercite <- spidercite %>% 
  select(, c(2,3,4,5,6,9,10)) %>% 
  rename(authors = Author,
         title = Title,
         source = "Publication.Title",
         document = "Item.Type",
         DOI = DOI,
         link = Url,
         year = "Publication.Year"
  ) %>%
  mutate(DOI = tolower(DOI)) %>% 
  mutate(
    DOI = {
      is_empty <- (DOI == "" | is.na(DOI))
      dummy_index <- cumsum(is_empty)
      if_else(is_empty, paste0("dummy_sc_", dummy_index), DOI)
    }
  )

all_records_inc_sc <- rbind(spidercite, all_records)

all_records_inc_sc <- all_records_inc_sc %>% 
  distinct(DOI, .keep_all = TRUE)

#######################################################################

#Manual check sorted for names - one dup left from a dummy DOI

all_records_inc_sc <- all_records_inc_sc %>% slice(-31)

write.csv(all_records_inc_sc, "datasets/4_SCOPUS_WoS_spidercite_records.csv") 

# File 4 is now ready for full text read and data extraction (File 5)

########################################################################
########################################################################
# Alternative de-dup
# It is possible use fuzzy matching for this

#fuzzy match (on title) using jaro-winkler distance

all_records_inc_sc <- all_records_inc_sc %>%
  mutate(normalised_title = str_trim(str_to_lower(title)))

# Generate pairs of rows with their string distance
title_matches <- expand.grid(row1 = 1:nrow(all_records_inc_sc), 
                             row2 = 1:nrow(all_records_inc_sc)) %>%
  filter(row1 < row2) %>%  # avoid self-comparison and duplicate pairs
  mutate(
    title1 = all_records_inc_sc$normalised_title[row1],
    title2 = all_records_inc_sc$normalised_title[row2],
    distance = stringdist(title1, title2, method = "jw") # Jaro-Winkler method
  ) %>%
  arrange(distance)

# threshold
potential_duplicates <- title_matches %>% filter(distance < 0.2)

potential_duplicates




