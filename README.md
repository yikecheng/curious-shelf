# Curious Shelf

**Curious Shelf** is a personal terminal book manager for following ideas across artificial intelligence, design, behavioral science, cities, writing, and speculative fiction. It keeps a reading library, enriches known titles from an offline catalog, searches and updates the shelf, and turns three concurrent recommendation signals into one explainable shortlist.

## Run it

The application is written for Bash and uses [Gum](https://github.com/charmbracelet/gum) for its rich menu, prompts, selections, and styling.

```bash
brew install gum
chmod +x app.sh
./app.sh
```

Gum is recommended, but every interaction also has a numbered portable fallback. No API keys or network connection are required. Run the automated checks with:

```bash
./tests/run_tests.sh
```

## Architecture

The program follows `UI → Workflows → Components → Data Layer → Storage`. `app.sh` only initializes storage and opens the menu. Scripts under `ui/` own Gum presentation and input; `workflows/` connect complete user actions; `books/` and `recommendations/` are small components with pipe-friendly text interfaces; and `data/book_database.sh` is the only application file allowed to read or write `data/books.csv`. Records cross layer boundaries as predictable pipe-delimited lines, making each step easy to inspect.

The recommendation workflow starts history, interest, and discovery readers in the background with `&`, captures every `$!`, shows an elapsed progress line, and synchronizes them with `wait`. It then demonstrates composition with a real pipeline:

```bash
cat history.txt interests.txt discovery.txt \
  | recommendations/refine_recommendations.sh \
  > final.txt
```

Refinement adds small profile-fit bonuses, removes duplicates and saved books, limits any one genre to two results, and returns six ranked choices.

## Personalization

My shelf is organized around a question: **how do people design, understand, and live inside complex systems?** The initial library connects AI, human behavior, design, cities, writing, and fiction rather than staying in one genre. The editable **reading lens** adds two practical constraints—preferred pace and comfortable page count—so recommendations fit both intellectual interests and the kind of reading I want right now. The dashboard, cross-genre discovery reader, and ability to queue a recommendation make the tool useful beyond the assignment demo.

## Useful component commands

```bash
# Search accepts an argument or stdin.
./books/search_books.sh "design"
printf 'reading\n' | ./books/search_books.sh

# Enrich a title through a pipe.
printf 'The Alignment Problem|Brian Christian\n' \
  | ./books/fetch_book_metadata.sh

# Run all three recommendation readers without an interactive save prompt.
BOOK_MANAGER_AGENT_DELAY=0 ./workflows/get_recommendations.sh --non-interactive
```

## Demo video

**[Watch the live narrated demo on Google Drive](https://drive.google.com/file/d/1VzeKG3o_Zqaye29xWsBfbV1PZaaAyEeU/view).** It shows the Gum interface, reading dashboard, library search, parallel recommendation progress, and refined shortlist.

A downloadable copy is also stored in [`demo/curious-shelf-demo.mp4`](demo/curious-shelf-demo.mp4). GitHub may not preview the repository copy inline because of its file size; use the Google Drive link above for immediate playback. The narration and shot list are in [`DEMO_SCRIPT.md`](DEMO_SCRIPT.md).

## Project map

```text
app.sh
├── ui/                 Gum screens and portable interaction helpers
├── workflows/          Complete library and recommendation flows
├── books/              Metadata enrichment and search components
├── recommendations/    Three agents plus pipeline refinement
├── data/               Database boundary, profile, catalog, and storage
├── tests/               Isolated end-to-end checks
└── demo/                Narrated walkthrough
```
