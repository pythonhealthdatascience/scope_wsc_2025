# TOPIC MODELLING

#install.packages("pdftools")
#library(pdftools)

#install.packages(c("tm", "topicmodels", "tidyverse", "tidytext"))
library(tm)
library(topicmodels)
library(tidyverse)
library(tidytext)
library(reshape2)
library(textstem)
library(textmineR)
library(Matrix)



##############################################################################
#convert pdfs to text file - ONCE ONLY

# # List all PDFs in folder
# pdf_files <- list.files("files/", pattern = "\\.pdf$", full.names = TRUE)
# 
# # Loop through files and convert them
# for (pdf in pdf_files) {
#   
#   pdf_text <- pdf_text(pdf)
#   pdf_text_combined <- paste(pdf_text, collapse = "\n")
#   
#   # Create a filename for the text file
#   txt_file <- paste0(tools::file_path_sans_ext(basename(pdf)), ".txt")
#   
#   # Save the text file 
#   writeLines(pdf_text_combined, file.path("texts/", txt_file))
# }

#############################################################################
# Topic modelling
# Update the default stopwords with common words using tf-idf - this creates a list
# of words that are common across all documents, therefore not useful
# Then create term document matrix

# Read files into a corpus
file_path <- "texts/" 

corpus <- VCorpus(DirSource(file_path, encoding = "UTF-8"), readerControl = list(language = "en"))

# lemmatize as many similar words
lemmatize_corpus <- content_transformer(function(x) {
  lemmatize_strings(x)
})

# standardise American/British spelling with American for WSC
standardize_spelling <- content_transformer(function(x) {
  # Replace British spellings with American ones
  x <- gsub("\\butilis", "utiliz", x) 
  x <- gsub("orthopaed", "orthoped", x)
  x <- gsub("theatre", "theater", x)
  return(x)
})

# Initial clean before creating stopword list with tf-idf
clean_corpus <- corpus %>%
  tm_map(content_transformer(tolower)) %>%
  tm_map(removeNumbers) %>%
  tm_map(removePunctuation) %>%
  tm_map(stripWhitespace) %>%
  tm_map(standardize_spelling) %>% 
  tm_map(lemmatize_corpus)

# tf-idf to find unique words
dtm <- DocumentTermMatrix(clean_corpus)
# Convert to tidy format
tidy_dtm <- tidy(dtm)
# Calculate tf-idf
tf_idf <- tidy_dtm %>%
  bind_tf_idf(term, document, count) %>%
  arrange(desc(tf_idf))
# See top tf-idf terms per document
tf_idf %>%
  group_by(document) %>%
  slice_max(tf_idf, n = 5) %>%
  ungroup()

#filter the not unique words - manual check for idf threshold
common_words <- tf_idf %>%
  select(term, idf) %>%
  distinct() %>%
  arrange(idf) %>%
  filter(idf<0.1)

# Default English stopword dictionary
stopwords_en <- stopwords("en")
# Check intersection (common words already in stopwords)
already_in_stopwords <- base::intersect(common_words, stopwords_en)
# Check words NOT in stopwords - will add in
not_in_stopwords <- base::setdiff(common_words, stopwords_en)

# Check results 
cat("Already in stopwords:\n")
print(already_in_stopwords)

cat("\nNot yet in stopwords (consider adding these):\n")
print(not_in_stopwords$term)

# extra manual add to stopwords
manual_stopwords <- c("bmj", "data", "min", "tfc", "vfc", 
                      "authors", "used", "tests", "results",
                      "admin", "based", "dovepress", "thus",
                      "des", "additional", "room", "average",
                      "room", "type", "journal", "unit", "problem", 
                      "minute", "year", "hour", "operation",
                      "mean", "factor", "online", "term", "determine",
                      "lead", "propose", "project", "image", "open", "author",
                      "option", "far", "report", "site", "dedicate", "different",
                      "run", "wiley", "week", "area", "work", "engineer",
                      "figure", "different", "within", "length", "parameter",
                      "develop", "ﬂow", "key", "identify", "publish", "stay",
                      "without", "library", "complete", "solution", "many",
                      "vol", "accord", "implementation", "assessment")

# Add to stopwords list
all_stopwords <- c(stopwords_en, not_in_stopwords$term, manual_stopwords)

# Pre-processing corpus- much of this has been done but double checking
clean_corpus <- clean_corpus %>%
  tm_map(content_transformer(tolower)) %>%
  tm_map(removeNumbers) %>%
  tm_map(removePunctuation) %>%
  tm_map(removeWords, all_stopwords) %>%
  tm_map(stripWhitespace)

# Document-Term Matrix (DTM)
dtm <- DocumentTermMatrix(clean_corpus)

# Optional: remove sparse terms (recommended)
dtm <- removeSparseTerms(dtm, sparse = 0.90) # Adjust sparsity as needed

########################################################################

#Run LDA (Topic Modeling)
# Choose number of topics (k) by manual inspection of results
# k=3 makes a clear set of topics after full read of all papers
# Set seed for reproducible analysis

k <- 3
lda_model <- LDA(dtm, k = k, method = "Gibbs", control = list(seed = 1234))

# Explore results
terms_per_topic <- terms(lda_model, 10) # top 10 terms per topic
print(terms_per_topic)

# Topic proportions per document
doc_topics <- tidy(lda_model, matrix = "gamma")
print(doc_topics)

###########################################################################
# Plot topics top ten terms

topics_terms <- tidy(lda_model, matrix = "beta")

top_terms <- topics_terms %>%
  group_by(topic) %>%
  slice_max(beta, n = 10) %>%
  ungroup() %>%
  arrange(topic, -beta)

topics <- top_terms %>%
  mutate(term = reorder_within(term, beta, topic)) %>%
  ggplot(aes(beta, term, fill = factor(topic))) +
  geom_col(width = 0.5, show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  scale_y_reordered() +
  labs(x = "Beta", y = "Term", title = "Top Terms per Topic")


ggsave("images/topics.pdf", plot = topics, device = "pdf", width = 11, height = 4)
topics
#####################################################
# find k
#  perplexity calculation
# This is used for predictive performance on large corpuses
# We are more interested in interpretability so not using perplexity score
# which recommends up to 15 clusters, and will fragment the dataset too much.

dtm_train <- dtm[1:33, ]  # example training set
dtm_test <- dtm[33:37, ]  # example test set

k_values <- seq(2, 15, by=1)
perplexity_values <- numeric(length(k_values))

for(i in seq_along(k_values)){
  lda_temp <- LDA(dtm_train, k = k_values[i], method = "Gibbs", control = list(seed = 123))
  perplexity_values[i] <- perplexity(lda_temp, newdata = dtm_test)
}

plot(k_values, perplexity_values, type = "b",
     xlab = "Number of Topics (k)",
     ylab = "Perplexity",
     main = "Perplexity for varying number of topics")

########################################################################## 

# Topic distribution per document
doc_topics <- topicmodels::posterior(lda_model)$topics
dominant_topic <- apply(doc_topics, 1, which.max)
data.frame(Document = rownames(doc_topics), DominantTopic = dominant_topic)

######################################################################

# Merge topics into dataset for analysis

# Print top terms per topic - inspect all terms to interpret
top_terms2 <- tidy(lda_model, matrix = "beta") %>%
  group_by(topic) %>%
  slice_max(beta, n = 5) %>%
  summarise(terms = paste(term, collapse = ", "))

print(top_terms2)

# Assign topics to documents - inspect documents/terms to interpret
doc_topics2 <- tidy(lda_model, matrix = "gamma") %>%
  group_by(document) %>%
  slice_max(gamma, n = 1) %>%
  left_join(top_terms2, by = c("topic"))

doc_topics2 <- doc_topics2 %>%
  arrange(tolower(document))

# Merge topic labels back to original data
data <- read.csv("datasets/7_fullset_authors.csv")
doc_topics2$document_id <- as.character(data$X)

# add id to merge on, and remove unnecessary columns
data$document_id <- as.character(data$X)
data_final <- data %>%
  left_join(doc_topics2, by = c("document_id" = "document_id")) %>% 
  select(-c(1,2,34)) %>% 
  rename(document_type = document.x)

# save final dataset for generating analysis and plots
write.csv(data_final, "datasets/8_complete_data_with_topics.csv")

############################################################
# Internal evaluation
# Extract the topic-word distributions (phi matrix) from LDA
phi <- topicmodels::posterior(lda_model)$terms

# For each topic, get the top 20 words - 30 used for manual inspection
top_words <- GetTopTerms(phi, 20)

# Convert dtm to a standard sparse matrix
dtm_matrix <- as.matrix(dtm)
dtm_sparse  <- Matrix(dtm_matrix, sparse = TRUE)
# Compute probability-based coherence for each topic using sparse dtm.
# M is the number of top words to use.
topic_coherence <- CalcProbCoherence(phi = phi, dtm = dtm_sparse, M = 20)

# Topic Coherence

mean_coherence <- mean(topic_coherence)
cat("Topic Coherence per Topic:\n")
print(topic_coherence)
cat("Mean Topic Coherence:", mean_coherence, "\n")

# Topic Diversity

unique_words <- length(unique(as.vector(top_words)))
total_words <- length(top_words)
topic_diversity <- unique_words / total_words
cat("Topic Diversity:", topic_diversity, "\n")

# Word Entropy

word_entropy <- apply(phi, 1, function(topic_probs) {
  topic_probs <- topic_probs[topic_probs > 0]
  -sum(topic_probs * log(topic_probs))
})
avg_entropy <- mean(word_entropy)
cat("Word Entropy per Topic:\n")
print(word_entropy)
cat("Average Word Entropy:", avg_entropy, "\n")
