# Annotato

> Automatically adds schema comments (columns, indexes, triggers, enums) to Rails models.

![CI](https://github.com/boserh/annotato/actions/workflows/ci.yml/badge.svg)
[![Gem Version](https://badge.fury.io/rb/annotato.svg)](https://badge.fury.io/rb/annotato)

---

## Features

- Annotates Rails models with:
  - Columns and types
  - Default values and constraints
  - Enums with values
  - Indexes (only if present)
  - Triggers (only if present)
- Skips unchanged annotations
- Replaces legacy `annotate`/`annotate_models` blocks
- Smart formatting with aligned columns

Example:

```ruby
# == Annotato Schema Info
# Table: users
#
# Columns:
#  id         :bigint           not null, primary key
#  email      :string           not null, unique
#  role       :string           default("user"), not null
#
# Enums:
#  role: { user, admin }

class User < ApplicationRecord
end
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

To annotate all models:

```bash
bundle exec rake annotato:models
```

---

## Rake Task

```bash
rake annotato:models
```

- Automatically loads all models via `Rails.application.eager_load!`
- Modifies model files in place
- Existing Annotato and Annotate blocks will be replaced

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
