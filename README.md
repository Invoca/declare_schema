# HoboFields

Rich field types and migration-generator for Rails.

## Testing
To run tests:
```
rake test:prepare_testapp[force]
cat test_responses.txt | rake test:all
```
(Note: there currently are no unit tests. The above will run the `rdoctests`.)
