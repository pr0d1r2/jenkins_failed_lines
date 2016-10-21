# jenkins_failed_lines

Get failing lines from jenkins reports. Greately improve speed of
re-creating issues locally.

## Setup

```bash
export JENKINS_LOGIN="xxx"
export JENKINS_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Usage

### rspec

```bash
bundle exec ruby jenkins_failed_lines.rb https://jenkins.example.com/job/pr-specs/8472/
```

Or:

```bash
bundle exec ruby jenkins_failed_lines.rb https://jenkins.example.com/job/pr-specs/8472/testReport/
```

Which results in:

```
spec/model/user_spec:11
spec/model/profile_spec:69
```

### cucumber

```bash
bundle exec ruby jenkins_failed_lines.rb https://jenkins.example.com/job/pr-features/8472/
```

Or:

```bash
bundle exec ruby jenkins_failed_lines.rb https://jenkins.example.com/job/pr-features/8472/testReport/
```

Which results in:

```
features/profile.feature:21
features/profile.feature:44
```

## Advanced usage

Run:

```bash
bundle exec rspec `bundle exec ruby jenkins_failed_lines.rb https://jenkins.example.com/job/pr-specs/8472/ https://jenkins.example.com/job/pr-specs/8888/ https://jenkins.example.com/job/pr-specs/10999/`
```

And go make a coffee.
