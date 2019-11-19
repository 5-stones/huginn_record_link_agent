# RecordLinkAgent

The Record Link Agent is designed to maintain bidirectional relationships betweeen systems that don't have reliable support for external IDs.

## Installation

This gem is run as part of the [Huginn](https://github.com/huginn/huginn) project. If you haven't already, follow the [Getting Started](https://github.com/huginn/huginn#getting-started) instructions there.

Add this string to your Huginn's .env `ADDITIONAL_GEMS` configuration:

```ruby
huginn_http_request_agent
# when only using this agent gem it should look like this:
ADDITIONAL_GEMS=huginn_http_request_agent
```

And then execute:

    $ bundle

## Usage

This agent requires additional database tables in your Huginn wnvironment for managing the record links. To install the migrations, run `bundle exec rake railties:install:migrations FROM=huginn_record_link_agent_engine` and then run `bin/rake db:migrate` to apply the required migrations.

Instructions for using the agent can be found in the agent's description: `lib/huginn_record_link_agent/http_record_link_agent.rb`

## Development

Running `rake` will clone and set up Huginn in `spec/huginn` to run the specs of the Gem in Huginn as if they would be build-in Agents. The desired Huginn repository and branch can be modified in the `Rakefile`:

```ruby
HuginnAgent.load_tasks(branch: '<your branch>', remote: 'https://github.com/<github user>/huginn.git')
```

Make sure to delete the `spec/huginn` directory and re-run `rake` after changing the `remote` to update the Huginn source code.

After the setup is done `rake spec` will only run the tests, without cloning the Huginn source again.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Release

The standard release command for this project is:
```
npm version [<newversion> | major | minor | patch | premajor | preminor | prepatch | prerelease | from-git]
```

This command will:

1. Generate/update the Changelog
1. Bump the package version
1. Tag & pushing the commit


e.g.

```
npm version 1.2.17
npm version patch // 1.2.17 -> 1.2.18
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/huginn_http_request_agent/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
