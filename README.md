# DeclareSchema

Declare your active_record model schemas and have database migrations generated for you!

## Testing
To run tests:
```
rake test:prepare_testapp[force]
rake test:all < test_responses.txt
```
(Note: there currently are no unit tests. The above will run the `rdoctests`.)
