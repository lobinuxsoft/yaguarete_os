// Content collections.
//
// The ScrewFast template shipped `products`, `blog`, `insights` and
// `docs` (Starlight) collections. None apply to YaguareteOS today —
// the landing is a single page with no blog or product catalogue, and
// ADRs live under the repo's `docs/adr/` on GitHub directly. Export
// an empty `collections` object so Astro keeps `astro:content`
// typings happy without registering anything.
//
// When we ship blog posts or release notes, define the collection
// here per https://docs.astro.build/en/guides/content-collections/.

export const collections = {};
