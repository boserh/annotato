# Annotato

> Automatically adds schema comments (columns, indexes, triggers, enums) to Rails models.

![CI](https://github.com/boserh/annotato/actions/workflows/ci.yml/badge.svg)
[![Gem Version](https://badge.fury.io/rb/annotato.svg)](https://badge.fury.io/rb/annotato)

---

## Features

* Annotates Rails models with:

  * Columns and types
  * Default values (including database functions like `now()`) and constraints
  * Table and column comments
  * PostgreSQL native enums with their values
  * Indexes with method, order, `INCLUDE` and `WHERE` clauses (only if present)
  * Triggers (only if present)
  * Check Constraints (only if present)
* Works with PostgreSQL, MySQL/Trilogy and SQLite (enums are PostgreSQL-only)
* Supports multiple databases (each model uses its own connection)
* Skips unchanged annotations and replaces legacy `annotate` gem blocks
* Only writes files inside your application (never engine or gem models)
* Smart formatting with aligned columns

Example (the annotation is appended to the end of the model file):

```ruby
class User < ApplicationRecord
end

# == Annotato Schema Info
# Table: users
# Comment: People who can log in
#
# Columns:
#  id         :bigint not null, primary key
#  email      :character varying not null, unique
#  role       :user_role default("member"), not null, enum
#  created_at :timestamp(6) without time zone default(now()), not null
#
# Enums:
#  role (user_role): [
#    member,
#    admin
#  ]
#
# Indexes:
#  index_users_on_email (email) unique
```

---

## Installation

Add this line to your Gemfile:

```ruby
gem "annotato"
```

Then run:

```bash
bundle install
```

---

## Usage

### Annotate All Models

To annotate all models, run:

```bash
bundle exec rake annotato:models
```

### Annotate Specific Models

You can pass one or multiple model names to the task, as task arguments or via `MODEL`.

```bash
# Annotate only the User model
rake annotato:models[User]

# Annotate multiple models (User and Admin::Account)
rake "annotato:models[User,Admin::Account]"
MODEL=User,Admin::Account rake annotato:models
```

Unknown names are reported and skipped.

### Check Annotations in CI

`annotato:check` writes nothing and exits with a non-zero status if any annotation is missing or outdated:

```bash
bundle exec rake annotato:check
```

### Automatic Annotation After Migrations

In the `development` environment, models are re-annotated automatically after
`db:migrate`, `db:rollback` and their variants (`db:migrate:primary`, `db:migrate:up`, ...).
Other environments (production, CI) never rewrite model files.

To turn it off locally:

```bash
ANNOTATO_SKIP=1 rake db:migrate
```

---

## Rake Tasks

```bash
rake annotato:models[MODEL]
rake annotato:check[MODEL]
```

* Automatically loads all models via `Rails.application.eager_load!`
* Modifies model files in place (atomically, via a temp file)
* Replaces existing Annotato and legacy annotate blocks
* **Pass `MODEL` argument (single or comma-separated) to target specific models**

---

## Development

To run tests:

```bash
bundle exec rspec
```

To check code coverage:

```bash
COVERAGE=true bundle exec rspec
```

---

## Contributing

Feel free to open issues or pull requests.

---

## License

MIT
