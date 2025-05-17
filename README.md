# Annotato

> Automatically adds schema comments (columns, indexes, triggers, enums) to Rails models.

![CI](https://github.com/boserh/annotato/actions/workflows/ci.yml/badge.svg)
[![Gem Version](https://badge.fury.io/rb/annotato.svg)](https://badge.fury.io/rb/annotato)

---

## Features

* Annotates Rails models with:

  * Columns and types
  * Default values and constraints
  * Enums with values
  * Indexes (only if present)
  * Triggers (only if present)
* Skips unchanged annotations
* Smart formatting with aligned columns

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

### Annotate All Models

To annotate all models, run:

```bash
bundle exec rake annotato:models
```

### Annotate Specific Models

You can now pass one or multiple model names to the task.

```bash
# Annotate only the User model
rake annotato:models[User]

# Annotate multiple models (User and Admin::Account)
rake annotato:models["User,Admin::Account"]
```

---

## Rake Task

```bash
rake annotato:models[MODEL]
```

* Automatically loads all models via `Rails.application.eager_load!`
* Modifies model files in place
* Replace existing Annotato and legacy annotate blocks
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
