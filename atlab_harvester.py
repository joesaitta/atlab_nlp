"""
Grab script text form the Avatarspirit website
"""

from __future__ import print_function

import requests
import re
from bs4 import BeautifulSoup
import pandas as pd
import os
import time
import matplotlib as mpl
mpl.use('TkAgg')
import matplotlib.pyplot as plt


# Each episode fetched http://atla.avatarspirit.net/transcripts.php?num=101
# BASE_URL = "http://atla.avatarspirit.net/transcripts.p
#  selector path = body > table > tbody > tr > td.content > div.content > blockquotehp"

EPI_URL = 'http://avatar.wikia.com/wiki/Avatar_Wiki:Transcripts'

# Trying to pull from wikia instead, they have a tabular format
BASE_URL = "http://avatar.wikia.com/wiki/Transcript:"
OUTPUT_PATH = '/Users/joesaitta/iCloud/school/2018_fall/DS745_Viz/project_3'

# Get episode titles
def get_episodes():

    url = EPI_URL
    resp = requests.get(url)
    url_text = resp.text
    soup = BeautifulSoup(url_text, features="html.parser")

    # Content of the script (0th element is the intro, 1st is the script)
    wikitables = soup.body.findAll('table', 'wikitable')

    episodes = []
    for wikitable in wikitables:
        for row in wikitable.childGenerator():
            episode_number = row.find('th')
            if episode_number != -1 and episode_number is not None:
                episode_number = episode_number.get_text()

                title = row.find('a').get_text()
                line = [episode_number.strip(), title.strip()]

                episodes.append(line)

    episodes_df = pd.DataFrame(episodes, columns=['num','title'])

    # Label the seasons (first 2 are 20 episodes, 3rd is 22)
    episodes_df['season'] = None
    episodes_df.loc[1:21,'season'] = 1
    episodes_df.loc[21:41,'season'] = 2
    episodes_df.loc[41:63,'season'] = 3
    # Just keep the Avatar episodes
    return episodes_df[:63]


# Grab one script at a time
def get_transcripts(title, episode_num, season):

    url = BASE_URL + str(title)
    print("Downloading episode %s" % url)
    resp = requests.get(url)
    url_text = resp.text
    soup = BeautifulSoup(url_text, features="html.parser")

    # Content of the script (0th element is the intro, 1st is the script)
    wikitables = soup.body.findAll('table', 'wikitable')

    body_text = []
    for wikitable in wikitables:
        for row in wikitable.childGenerator():
            character = row.find('th')
            if character != -1 and character is not None:
                character = character.get_text()

                dialog = row.find('td').get_text()
                dialog = re.sub("[\(\[].*?[\)\]]", "", dialog)
                line = [character.strip(), dialog.strip().encode('utf8')]

                body_text.append(line)
    script_df = pd.DataFrame(body_text, columns=['character','dialog'])

    # Dump to disk
    outfile = os.path.join(OUTPUT_PATH, str(season) + "_" +
                           str(episode_num) + "_" +
                           title + '.csv')
    script_df.to_csv(outfile)

if __name__ == "__main__":

    # episodes_df = get_episodes()
    # for episode in episodes_df.itertuples():
    #     # Pause between pulling down episodes
    #     time.sleep(5)
    #     get_transcripts(episode.title, episode.num, episode.season)

    files = glob.glob(os.path.join(OUTPUT_PATH, '*.csv'))
    df = None
    for f in files:
        title = f.split('/')[-1]
        episode = '_'.join(title.split('_')[0:2])
        if df is None:
            df = pd.read_csv(f, index_col=0)
            df['episode'] = episode
        else:
            tmp = pd.read_csv(f, index_col=0)
            tmp['episode'] = episode
            df = df.append(tmp)

    df.to_csv(os.path.join(OUTPUT_PATH, 'all_episodes.csv'), index=False)

    # Group text by episode
    df_episode_list = []
    for id, v in df.groupby('episode'):
        dialog_str = ' '.join(v.dialog.values)
        df_episode_list.append([id, dialog_str])
    df_epi = pd.DataFrame(df_episode_list, columns=['id','dialog'])

    # Dump to disk and finish up in R
    df_epi.to_csv(os.path.join(OUTPUT_PATH, 'episode_dialog.csv'), index=False)


