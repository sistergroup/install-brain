---
type: meta
tags: [meta]
---

# Companies

One folder per company {{OWNER_NAME}} actually works with — their own employer, other
companies in the same group once there is real work with them, and outside companies whose people
they deal with.

Each folder holds one file:

```
Companies/<Company Name>/
  profile.md          what the company does, structure, internal language,
                      rhythms, who works there, the AI work there
```

People are not filed under companies. They live in the top-level `People/` folder, one
note each, with a `company` field pointing back here — so a person who changes employer
keeps one note, and someone who spans two companies is not duplicated. Each `profile.md`
keeps a `## People` section of wikilinks to them.

Start a new one from `Meta/Templates/Company Profile.md`, and read
`Meta/Vault Guide.md` for the rules — especially the `aliases` requirement, without
which a `[[Company Name]]` link will not resolve.

Do not scaffold a company before there is work with it. An empty profile that nobody
fills in is worse than no folder.
