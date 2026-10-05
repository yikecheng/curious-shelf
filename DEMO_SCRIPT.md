# Curious Shelf demo script

This is the narration used in the short repository video.

1. **Introduce the system.** “This is Curious Shelf, my terminal book manager for ideas at the intersection of technology, design, human behavior, cities, writing, and fiction. The opening dashboard makes my current shelf and reading profile visible.”
2. **Trace a library operation.** “Search accepts either an argument or standard input. Here the word design is piped into the search component. That component asks the data layer for matches, so no UI or workflow script touches the CSV file directly.”
3. **Show enrichment.** “A title and author can also move through a metadata component. The local catalog adds genre, year, length, pace, and a link without an API key, keeping the program reliable and understandable.”
4. **Demonstrate concurrency and composition.** “The recommendation workflow launches three independent readers at once. History follows strong shelf signals, interests uses my editable reading lens, and discovery deliberately leaves familiar genres. Bash process IDs and wait synchronize them.”
5. **Explain the result.** “Their files are combined with a pipe into refinement. It removes duplicates and books I already have, adds small pace and page-budget bonuses, limits genre repetition, and displays an explainable shortlist. The whole path is UI to workflow to components to the data boundary and back.”
