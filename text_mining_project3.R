# Joe Saitta - 2018-12-8
# Topic Modeling Avatar the Last Airbender

library(mallet)
library(reshape2)
library(ggplot2)
library(wordcloud)
# Use the gnome stop words file, in the current working directory
STOPWORDS = "english.stop"

# Downloaded from here
#STOPWORDS = "http://ftp.gnome.org/mirror/archive/ftp.sunet.se/pub/databases/full-text/smart/english.stop"

# This stackoverflow post saved the day https://stackoverflow.com/questions/30738974/rjava-load-error-in-rstudio-r-after-upgrading-to-osx-yosemite

# Not chunking here - each episode being treated as a chunk (preserving some context)
# Read in the csv set up in Python
df = read.csv("episode_dialog.csv", header=TRUE, stringsAsFactors = FALSE)
df = df[order(df$id),]

# Clean up the text, lowercase and remove punctuation (keep apostrophes)
df$dialog = tolower(df$dialog)
df$dialog = gsub("[^[:alnum:][:space:]' ]"," ", df$dialog)

# Turn each episode string into a word vector
df$dialog.v = strsplit(df$dialog, "\\s+")

# Turn the list of words into a string
df$dialog.v = lapply(df$dialog.v, paste, collapse = " ")

# Start processing with mallet, retain apostrophes
mallet.instances = mallet.import(df$id, df$dialog,
                                 STOPWORDS, FALSE, 
                                 token.regexp = "[\\p{L}']+")

# Create a topic trainer object - start with 25 possible topics
topic.model = MalletLDA(num.topics=12)

# Fill the trainer object with data
topic.model$loadDocuments(mallet.instances)
vocabulary = topic.model$getVocabulary()
length(vocabulary)

# What are the top 10 words
word.freqs = mallet.word.freqs(topic.model)
word.freqs[order(-word.freqs$term.freq),][1:10,]

# Set hyperparameters
# topic.model$setAlphaOptimization(40, 80)
topic.model$train(400)

# Get the proportion of words about each topic for each episode
episode.topics.m = mallet.doc.topics(topic.model, 
                                     smoothed=TRUE, 
                                     normalized=TRUE)

# Convert the doc topics into a dataframe, columns are topics, rows are episodes
episode.topics.df = as.data.frame(episode.topics.m)
episode.topics.df = cbind(df$id, episode.topics.df)

# Unpack the model
topic.words.m = mallet.topic.words(topic.model, smoothed=TRUE,
                                   normalized=TRUE)
colnames(topic.words.m) = vocabulary

# Get the 3 most probable words for each topic
topic.labels = mallet.topic.labels(topic.model, topic.words.m)

# Plot the topic proportion for each episode for all topics
# Change the column names for the episode.topics
colnames(episode.topics.df) = c("id", topic.labels)
episode.topics.melted = melt(episode.topics.df, id.vars="id")
png("topicProportions.png", width=1200,height=500)
ggplot(episode.topics.melted, aes(x=factor(id), y = value)) + 
  facet_wrap(~variable) +
  geom_bar(aes(fill = factor(id)), stat = "identity") +
  labs(title = "Avatar: The Last Airbender Topic Modeling", 
       subtitle = "Topic proportions for each episode over the course of the series", 
       x ="Episode ID") +
  theme(legend.position="none") +
  theme(plot.title=element_text(size=22)) +
  theme(plot.subtitle=element_text(size=18)) +
  theme(axis.title.y=element_blank()) +
  theme(axis.title.x=element_text(size=14)) +
  theme(strip.text=element_text(size=16)) +
  theme(axis.text.x=element_text(size=4, angle=-90, vjust=0.5)) +
  theme(axis.text.y=element_text(size=14))
dev.off()

# Create a wordcloud for one of the topic rows
# keywords = c("fire","zuko")
keyword = "good"
# Get the topic with the highest concentration of these keywords
# imp.row = which(rowSums(topic.words.m[, keywords]) == max(rowSums(topic.words.m[,keywords])))
imp.row = which(topic.words.m[,keyword] == max(topic.words.m[,keyword]))
topic.top.words = mallet.top.words(topic.model, topic.words.m[imp.row,], 100)
png("wordcloud.png", width=1280,height=800)
wordcloud(topic.top.words$words, topic.top.words$weights, random.order=FALSE,
          # colors= c("indianred1","indianred2","indianred3","indianred"))
          colors = c("steelblue1","steelblue2","steelblue3","steelblue"))
dev.off()
