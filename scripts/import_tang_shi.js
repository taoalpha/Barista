const fs = require('fs');
const path = require('path');
const https = require('https');

const URL = 'https://raw.githubusercontent.com/xuchunyang/300/refs/heads/master/300.json';
const OUTPUT_FILE = path.join(__dirname, '../data/tang-shi.json');
const SOURCES_FILE = path.join(__dirname, '../data/sources.json');

function fetchJson(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', reject);
    });
}

function updateSourcesMetadata(filename) {
    let sources = [];
    if (fs.existsSync(SOURCES_FILE)) {
        sources = JSON.parse(fs.readFileSync(SOURCES_FILE, 'utf8'));
    }

    const sourceName = "Tang Shi 300";
    const existingIndex = sources.findIndex(s => s.name === sourceName);
    
    const newSource = {
        name: sourceName,
        description: "Three Hundred Tang Poems",
        updatedAt: Math.floor(Date.now() / 1000),
        filename: path.basename(filename),
        randomize: true
    };

    if (existingIndex !== -1) {
        sources[existingIndex] = newSource;
    } else {
        sources.push(newSource);
    }

    fs.writeFileSync(SOURCES_FILE, JSON.stringify(sources, null, 2));
    console.log(`Updated ${SOURCES_FILE} with source: ${sourceName}`);
}

async function main() {
    try {
        console.log(`Fetching poems from ${URL}...`);
        const poems = await fetchJson(URL);
        console.log(`Fetched ${poems.length} poems.`);

        const baristaItems = poems.map(poem => {
            // Text: contents (newlines -> spaces) + author
            const flatContent = poem.contents.replace(/\n/g, ' ');
            const text = `${flatContent} — ${poem.author}`;

            // FullText: title - (author, type) \n content
            const fullText = `${poem.title} - (${poem.author}, ${poem.type})\n\n${poem.contents}`;

            return {
                text: text,
                fullText: fullText,
                link: null, // No specific link provided
                isFavoritable: true
            };
        });

        // Write content file
        fs.writeFileSync(OUTPUT_FILE, JSON.stringify(baristaItems, null, 2));
        console.log(`Wrote ${baristaItems.length} items to ${OUTPUT_FILE}`);

        // Update sources.json
        updateSourcesMetadata(OUTPUT_FILE);

    } catch (error) {
        console.error('Failed to import Tang Shi:', error);
        process.exit(1);
    }
}

main();
