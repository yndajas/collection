# Collection

## Preparing the database

To set up the database, run:

```bash
bin/rails db:prepare
```

To seed the database with initial data:

```bash
bin/rails db:seed
```

To reset the database (delete and recreate):

```bash
bin/rails db:reset
```

## Managing credentials

You need the `config/master.key` to manage the encrypted credentials.

To edit the credentials:

```bash
bin/rails credentials:edit
```

To see the current credentials:

```bash
bin/rails credentials:show
```

## AI disclosure

This project was developed with the assistance of Gemini.
