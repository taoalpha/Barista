const fs = require('fs');
const path = require('path');

const NEWS_API_KEY = process.env.NEWS_API_KEY;
const DATA_DIR = path.join(__dirname, '../data');
const SOURCES_FILE = path.join(DATA_DIR, 'sources.json');
const country = process.argv[2] || 'us';
const OUTPUT_FILE = path.join(DATA_DIR, `top-headlines-${country}.json`);

if (!NEWS_API_KEY) {
  console.error('Error: NEWS_API_KEY environment variable is not set.');
  process.exit(1);
}

async function fetchNews() {
  try {
    const url = `https://newsapi.org/v2/top-headlines?country=${country}&apiKey=${NEWS_API_KEY}`;
    console.log(`Fetching news for ${country} from:`, url.replace(NEWS_API_KEY, 'HIDDEN_KEY'));
    
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    if (data.status !== 'ok') {
      throw new Error(`API Error: ${data.message}`);
    }
    
    const articles = data.articles || [];
    console.log(`Fetched ${articles.length} articles.`);
    
    const sourceFilename = `top-headlines-${country}.json`;
    const baristaItems = articles.map(article => ({
      text: article.title,
      fullText: article.description,
      link: article.url
    }));
    
    // Write content file
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(baristaItems, null, 2));
    console.log(`Wrote ${baristaItems.length} items to ${OUTPUT_FILE}`);
    
    // Update sources.json
    updateSourcesMetadata(sourceFilename);
    
  } catch (error) {
    console.error('Failed to fetch news:', error);
    process.exit(1);
  }
}

function updateSourcesMetadata(sourceFilename) {
  try {
    let sources = [];
    if (fs.existsSync(SOURCES_FILE)) {
      sources = JSON.parse(fs.readFileSync(SOURCES_FILE, 'utf8'));
    }
    
    const now = Math.floor(Date.now() / 1000);
    const sourceIndex = sources.findIndex(s => s.filename === sourceFilename);
    const countryUpper = country.toUpperCase();
    
    if (sourceIndex >= 0) {
      sources[sourceIndex].updatedAt = now;
      console.log(`Updated timestamp for existing source: ${sourceFilename}`);
    } else {
      sources.push({
        name: `Top Headlines (${countryUpper})`,
        description: `Latest headlines from NewsAPI for ${countryUpper}`,
        updatedAt: now,
        filename: sourceFilename
      });
      console.log(`Added new source: ${sourceFilename}`);
    }
    
    fs.writeFileSync(SOURCES_FILE, JSON.stringify(sources, null, 2));
    console.log(`Updated ${SOURCES_FILE}`);
    
  } catch (error) {
    console.error('Failed to update sources metadata:', error);
    process.exit(1);
  }
}

fetchNews();
