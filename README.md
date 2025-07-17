# GemLens

[![Gem Version](https://badge.fury.io/rb/gemlens.svg)](https://badge.fury.io/rb/gemlens)

**Gemlens** is a CLI tool to analyze the evolution of your `Gemfile` over time. It helps you track when gems were added, removed, or updated in a project — great for audits, debugging, or historical exploration.

---

## ✨ Features

- Track changes to gems across Git commits
- View added, removed, or updated gems with commit metadata
- Colorized timeline output for clarity
- Works on any Git-tracked Ruby project

---

## 🧰 Installation

Add this line to your application's Gemfile:

```ruby
gem 'gemlens'
```

Then execute:

```sh
$ bundle install
```

Or install it globally:

```sh
$ gem install gemlens
```

---

## 🚀 Usage

From any Git-tracked Ruby project:

```sh
$ bundle exec gemlens
```

You’ll get a timeline showing how your `Gemfile` has changed, for example:

```
📜 Gemfile History Timeline

🟩 2023-04-11  Added    pry                  by Jane Doe    ➜ PR #1234 | Add pry for debugging
🟥 2023-05-09  Removed  byebug               by Jane Doe    ➜ 4d3c1f0 | Remove unused gem
🟦 2023-06-12  Updated  rails (6.1.0 → 7.0.4) by John Smith  ➜ PR #2345 | Upgrade Rails
```

You can also pass a path to another repo:

```sh
$ bundle exec gemlens /path/to/another/repo
```

---

## 🔧 Development

To set up the project locally:

```sh
$ git clone https://github.com/BestBitsLab/gemlens.git
$ cd gemlens
$ bin/setup
```

You can experiment with the code via:

```sh
$ bin/console
```

To build and install the gem locally:

```sh
$ bundle exec rake install
```

To release a new version:

1. Update the version in `lib/gemlens/version.rb`
2. Run:

```sh
$ bundle exec rake release
```

This will tag, push, and publish to [RubyGems.org](https://rubygems.org).

---

## 🤝 Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/BestBitsLab/gemlens). This project is intended to be a safe, welcoming space for collaboration. Please read and follow the [code of conduct](https://github.com/BestBitsLab/gemlens/blob/main/CODE_OF_CONDUCT.md).

---

## 🪪 License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## 📜 Code of Conduct

Everyone interacting in the Gemlens project’s codebase, issue trackers, and other community spaces is expected to follow the [Code of Conduct](https://github.com/BestBitsLab/gemlens/blob/main/CODE_OF_CONDUCT.md).

---
