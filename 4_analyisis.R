library(tidyverse)
library(ggalluvial)
library(patchwork)


# Plots and analysis using topics

data <- read.csv("datasets/8_complete_data_with_topics.csv")

###########################################################################
#Plot by year for topic and document type - compare patchwork and facets
# Define the full range of years
year_range <- min(data$year, na.rm = TRUE):max(data$year, na.rm = TRUE)

# Plot for document_type
yearplot <- ggplot(data) +
  geom_bar(aes(x = factor(year), fill = document_type), color = "grey80") +
  theme_light() +
  scale_x_discrete(limits = as.character(year_range)) +
  theme(legend.position = c(0.01, 0.9), legend.justification = c(0, 1)) +
  labs(x = "", y = "Number of publications", title = "Year of Publication", 
       fill = NULL)

# Plot for Topic
topicplot <- ggplot(data) +
  geom_bar(aes(x = factor(year), fill = factor(topic)), color = "grey80") +
  theme_light() +
  scale_x_discrete(limits = as.character(year_range)) +
  scale_fill_discrete(labels = c("Topic 1", "Topic 2", "Topic 3")) +
  theme(legend.position = c(0.01, 0.9), legend.justification = c(0, 1)) +
  labs(x = "", y = "Number of publications", title = "Topic of Publication", 
       fill = NULL)

# Combine the two plots vertically (ncol = 2 for side-by-side) using patchwork
combined_plot <- yearplot + topicplot + plot_layout(ncol = 1)
combined_plot

##########################################################################
# Faceting
# Reshape data into a long format. 
data_long <- data %>%
  mutate(topic = as.character(topic)) %>%   # Convert topic to character
  pivot_longer(
    cols = c(document_type, topic),
    names_to = "category",
    values_to = "value" 
  )

data_long$value <- factor(data_long$value,
                          levels = c("Journal article", "Conference paper", "1", "2", "3"))

# Create facet plot
faceted_plot <- ggplot(data_long, aes(x = factor(year), fill = value)) +
  geom_bar(color = "grey80") +
  theme_light() +
  scale_x_discrete(limits = as.character(year_range)) +
  facet_wrap(~ category, nrow = 2,
             labeller = labeller(category = c(document_type = "Document Type",
                                              topic = "Topic"))) +
  scale_fill_manual(
    values = c("Journal article"    = "#00ba38",
               "Conference paper" = "#83b0fc",
               "1"    = "#f8766d",
               "2"    = "#C77CFF",
               "3"    = "#FF61CC"),
    labels = c("Journal Article", "Conference Paper","Topic 1", "Topic 2", "Topic 3")
  ) +
  labs(x = "", y = "Number of publications", fill = NULL, 
       title = "Publications by Year")

faceted_plot
ggsave("images/yearplot2.pdf", plot = faceted_plot, device = "pdf", width = 9, height = 4)

###############################################################################
# facet of topics per method and outcome kpi
# tidy data

data_plot_methods <- data %>%
  mutate(DES_minus_hybrid = DES - hybrid) %>%
  rename(DES2 = DES) %>% 
  rename(
    DES = DES_minus_hybrid,
    `DES+ABS` = ABS,
    `DES+SD` = SD,
    `DES+Other` = other,
    `Patient Satisfaction` = outcome_satisfaction,
    Efficiency = outcome_efficiency,
    Costs = outcome_costs,
    `Resource Utilisation` = outcome_resources
  ) %>% 
  mutate(topic = factor(topic))


# Define the columns for simulation methods and outcomes
simulation_cols <- c(simulation_cols <- c('DES', 'DES+ABS', 'DES+SD', 'DES+Other')
)
outcome_cols <- c('Patient Satisfaction', 'Efficiency', 'Costs', 
                  'Resource Utilisation')
# --- Compute counts for simulation methods per topic ---
# If the columns are binary indicators (0/1), summing gives counts
simulation_counts <- data_plot_methods %>%
  group_by(topic) %>%
  summarise(across(all_of(simulation_cols), ~ sum(. , na.rm = TRUE)))

simulation_counts_long <- simulation_counts %>%
  pivot_longer(cols = all_of(simulation_cols),
               names_to = "method",
               values_to = "count") %>%
  mutate(plot_type = "Method")

# --- Compute counts for outcomes per topic ---
outcome_counts <- data_plot_methods %>%
  group_by(topic) %>%
  summarise(across(all_of(outcome_cols), ~ sum(. , na.rm = TRUE)))

outcome_counts_long <- outcome_counts %>%
  pivot_longer(cols = all_of(outcome_cols),
               names_to = "outcome",
               values_to = "count") %>%
  mutate(plot_type = "Outcome")

# --- Combine the two datasets ---
combined_counts <- bind_rows(
  simulation_counts_long %>% rename(variable = method),
  outcome_counts_long %>% rename(variable = outcome)
)

combined_counts$variable <- factor(combined_counts$variable,
                          levels = c("DES", "DES+ABS", "DES+SD", "DES+Other", 
                                     "Efficiency", "Costs", 
                                     "Patient Satisfaction",
                                     "Resource Utilisation"))


# Create the facet plot
facet_plot <- ggplot(combined_counts, aes(x = count, y = fct_rev(topic), fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9),color="grey80") +
  facet_wrap(~ plot_type, nrow = 2) +
  scale_fill_manual(
    values = c("DES"    = "#00ba38",
               "DES+ABS" = "#83b0fc",
               "DES+SD"    = "#7CAE00",
               "DES+Other"    = "#00BFC4",
               "Efficiency" =  "#f8766d",
               "Costs" = "#FF61CC",
               "Patient Satisfaction"= "#C77CFF",
               "Resource Utilisation" =  "#CD9600")) +
  labs(x = "Count", y = "Topic", fill = "Category",
       title = "Counts per Topic: Methods and Outcomes") +
  theme_light()

facet_plot

ggsave("images/topics_method_outcomes.pdf", plot = facet_plot, device = "pdf", width = 9, height = 4)
###################################################################################

# Correlate topics with simulation methods and outcomes
simulation_cols <- c('DES', 'ABS', 'SD', 'hybrid')
outcome_cols <- c('outcome_satisfaction', 'outcome_efficiency', 'outcome_costs', 
                  'outcome_resources')

topic_simulation_corr <- data %>%
  group_by(terms) %>%
  summarise(across(all_of(simulation_cols), mean, na.rm = TRUE))

topic_outcome_corr <- data %>%
  group_by(terms) %>%
  summarise(across(all_of(outcome_cols), mean, na.rm = TRUE))

# Temporal distribution analysis
topic_temporal <- data %>%
  group_by(terms) %>%
  summarise(
    min_year = min(year, na.rm = TRUE),
    mean_year = mean(year, na.rm = TRUE),
    max_year = max(year, na.rm = TRUE),
    count = n()
  )

# View correlations 
print("Simulation method correlations per topic:")
print(topic_simulation_corr)

print("Outcome correlations per topic:")
print(topic_outcome_corr)

print("Temporal analysis per topic:")
print(topic_temporal)

###############################################################
## plots
#Simulation Usage: Visualizes topic-method associations.
#Outcome Analysis: Clarifies outcome emphasis per topic.
#Temporal Analysis:  historical trends or shifts.

# Calculate counts of documents per topic
topic_counts <- data %>%
  group_by(topic) %>%
  summarise(Count = n())

# Plot counts
counts_plot <- ggplot(topic_counts, aes(x = fct_rev(factor(topic)), y = Count)) +
  geom_bar(stat = "identity", fill="steelblue", color="grey80") +
  coord_flip() +
  labs(title = "Counts of Documents per Topic",
       x = "Topic",
       y = "Document Count") +
  theme_minimal()

ggsave("images/counts_plot.pdf", plot = counts_plot, device = "pdf", width = 9, 
       height = 3)
counts_plot
#######################################
# methods per topic
# Prepare data
simulation_corr_long <- data %>%
  group_by(topic) %>%
  summarise(across(c(DES, ABS, SD, other), mean, na.rm = TRUE)) %>%
  melt(id.vars = "topic")

# Compute boundaries for horizontal lines.
# The y-axis (factor(topic)) will have positions 1, 2, ..., n.
topic_levels <- levels(factor(simulation_corr_long$topic))
n_topics <- length(topic_levels)
# Calculate the y positions for the boundaries (between each row)
boundary_lines <- seq(0.5, n_topics + 0.5, by = 1)

method_topic <- ggplot(simulation_corr_long, aes(x = value, y = fct_rev(factor(topic)), 
                                                 fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  labs(title = "Simulation Methods Usage by Topic",
       x = "Proportion of Papers",
       y = "Topic",
       fill = "Method") +
  scale_fill_discrete(labels = c("DES", "ABS", "SD", 
                                 "Other")) +
  theme_minimal() +
  # Add horizontal lines at the boundaries between topics
  geom_hline(yintercept = boundary_lines, color = "grey", size = 0.5)

ggsave("images/method_topic.pdf", plot = method_topic, device = "pdf", width = 9, 
       height = 3)
method_topic

#########################################
# outcomes per topic
# Prepare data
outcome_corr_long <- data %>%
  group_by(topic) %>%
  summarise(across(c(outcome_satisfaction, outcome_efficiency, outcome_costs, 
                     outcome_resources), 
                   mean, na.rm = TRUE)) %>%
  melt(id.vars = "topic")

# Assuming outcome_corr_long is created as shown:
outcome_corr_long <- data %>%
  group_by(topic) %>%
  summarise(across(c(outcome_satisfaction, outcome_efficiency, outcome_costs, 
                     outcome_resources), 
                   mean, na.rm = TRUE)) %>%
  melt(id.vars = "topic")

# Compute the boundaries for the horizontal lines.
topic_levels <- levels(factor(outcome_corr_long$topic))
n_topics <- length(topic_levels)
boundary_lines <- seq(0.5, n_topics + 0.5, by = 1)

# Create the plot with updated legend names and horizontal bars
outcome_topic <- ggplot(outcome_corr_long, aes(x = value, y = fct_rev(factor(topic)), 
                                               fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  labs(title = "Key performance indicators (KPIs) by Topic",
       x = "Proportion of Papers",
       y = "Topic",
       fill = "Outcome") +
  scale_fill_discrete(labels = c("Patient satisfaction", "Efficiency", "Costs", 
                                 "Resource utilisation")) +
  theme_minimal() +
  # Add horizontal lines at the boundaries between topics
  geom_hline(yintercept = boundary_lines, color = "grey", size = 0.5)

# Save the plot as a PDF and display it
ggsave("images/outcome_topic.pdf", plot = outcome_topic, device = "pdf", width = 9, 
       height = 3)
outcome_topic

#######################################
# temporal topics

temporal <- ggplot(data, aes(x = year, y = as.factor(topic), 
                             fill = as.factor(topic))) +
  geom_boxplot(alpha = 0.7) +
  labs(title = "Temporal Distribution of Topics",
       x = "Year",
       y = "Topic") +
  theme_minimal() +
  scale_y_discrete(limits = rev)+
  theme(legend.position = "none")

ggsave("images/temporal.pdf", plot = temporal, device = "pdf", width = 9, 
       height = 3)
temporal

#############################################################################

#######################################
# implementation per topic
# Prepare data
implem_corr_long <- data %>%
  group_by(topic) %>%
  summarise(across(c(Imp_Y), mean, na.rm = TRUE)) %>%
  melt(id.vars = "topic")

# Compute boundaries for horizontal lines.

topic_levels <- levels(factor(implem_corr_long$topic))
n_topics <- length(topic_levels)
# Calculate the y positions for the boundaries (between each row)
boundary_lines <- seq(0.5, n_topics + 0.5, by = 1)

implem_topic <- ggplot(implem_corr_long, aes(x = value, y = fct_rev(factor(topic)), 
                                             fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  labs(title = "Adoption of recommendations by Topic",
       x = "Proportion of Papers",
       y = "Topic",
       fill = "Adoption") +
  theme_minimal() +
  theme(legend.position = "none") +
  # Add horizontal lines at the boundaries between topics
  geom_hline(yintercept = boundary_lines, color = "grey", size = 0.5)

ggsave("images/implem.pdf", plot = implem_topic, device = "pdf", width = 9, 
       height = 3)
implem_topic

#######################################
# emergecy-elective per topic
# Prepare data
emerg_corr_long <- data %>%
  group_by(topic) %>%
  summarise(across(c(unscheduled,scheduled), mean, na.rm = TRUE)) %>%
  melt(id.vars = "topic")

# Compute boundaries for horizontal lines.
emerg_levels <- levels(factor(emerg_corr_long$topic))
n_topics <- length(topic_levels)
# Calculate the y positions for the boundaries (between each row)
boundary_lines <- seq(0.5, n_topics + 0.5, by = 1)

emerg_topic <- ggplot(emerg_corr_long, aes(x = value, y = fct_rev(factor(topic)), 
                                           fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  labs(title = "Emergency or Elective focus by Topic",
       x = "Proportion of Papers",
       y = "Topic",
       fill = "Emergency") +
  theme_minimal() +
  scale_fill_discrete(labels = c("Unscheduled", "Scheduled")) +
  # Add horizontal lines at the boundaries between topics
  geom_hline(yintercept = boundary_lines, color = "grey", size = 0.5)

ggsave("images/emerg.pdf", plot = emerg_topic, device = "pdf", width = 9, 
       height = 3)
emerg_topic

##############################################################################
##############################################################################

topicfullset <- read.csv("datasets/8_complete_data_with_topics.csv")
# Sankey topic - application area - implementation

# Define department columns 
topicfullset <- topicfullset %>% rename(Wards = wards)
departments_cols <- c("ED", "Theatres", "OPD", "Wards")

# Pivot longer for the Department dimension and filter for valid (used) entries
dept_long <- topicfullset %>%
  pivot_longer(cols = all_of(departments_cols),
               names_to = "Department",
               values_to = "Department_used") %>%
  filter(Department_used == 1)

# Ensure that Topic and Imp_y are treated as categorical variables
dept_long <- dept_long %>%
  mutate(Imp_Y = ifelse(Imp_Y == 1, "Y", "N"),
         topic = factor(topic),
         Imp_y = factor(Imp_Y)) 


# Aggregate frequencies for the Sankey plot
agg_df <- dept_long %>%
  group_by(topic, Department, Imp_y) %>%
  summarise(Freq = n(), .groups = 'drop')

# Create the Sankey diagram using three axes: Topic, Department, and Imp_y
sankey_plot <- ggplot(agg_df,
                      aes(axis1 = topic, axis2 = Department, axis3 = Imp_y, y = Freq)) +
  geom_alluvium(aes(fill = topic), width = 1/12, alpha = 0.7, knot.pos = 0.4) +
  geom_stratum(width = 1/8, fill = "grey80", color = "grey40", size = 0.3) +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
  scale_x_discrete(limits = c("Topic", "Department", "Implementation"), expand = c(.05, .05)) +
  labs(title = "Topic, Department, and Implementation of Results",
       x = "",
       y = "Frequency") +
  theme_minimal() +
  theme(axis.text.y = element_blank(),
        axis.ticks = element_blank()) +
  theme(legend.position = "none") +
  geom_vline(xintercept = c(1.5, 2.5), color = "black", linetype = "dashed", linewidth = 0.4)

# Save the Sankey plot as a PDF and display it
ggsave("images/sankey_topic_department_imp_y.pdf", plot = sankey_plot, device = "pdf", width = 11, height = 4)
sankey_plot





