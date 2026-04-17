# E-Games profile notes

## Final decision
Do **not** integrate E-Games installer logic, menu branches, or install flows into our production installer.

Reasons:
- user explicitly does not want E-Games installer inside our product
- upstream explicitly says educational / not for production
- our product target is production installer
- official Bedolaga/Remnawave docs remain primary source of truth

## Allowed scope
Keep E-Games knowledge only as:
- compatibility note for already-existing customer environments
- troubleshooting reference when a user says their panel was previously installed that way
- source of awareness for auth/domain/reverse-proxy differences

## Not allowed scope
- no E-Games install mode in menu
- no bundled E-Games scripts
- no automatic E-Games deployment path
- no default branching based on E-Games unless user explicitly asks for troubleshooting an existing E-Games-based installation

## Practical use
If a customer already has E-Games-based Remnawave infra, we may:
- adapt troubleshooting expectations
- explain likely auth/proxy/domain differences
- avoid overwriting assumptions blindly

But our installer itself must stay on:
- official Bedolaga bot docs
- official Bedolaga cabinet docs
- official Remnawave docs
