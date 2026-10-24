|                              check_name                               |  expected  |   actual   | passes |
|-----------------------------------------------------------------------|-----------:|-----------:|--------|
| clean_users rows = raw users - test accounts                          | 5100.00    | 5100.00    | true   |
| no test-domain emails left in clean_users                             | 0.00       | 0.00       | true   |
| Unknown users = raw blank-channel non-test users                      | 72.00      | 72.00      | true   |
| Unknown users = channel_was_blank flag                                | 72.00      | 72.00      | true   |
| clean_orders rows = deduped raw orders of non-test users              | 5193.00    | 5193.00    | true   |
| clean delivered value = deduped raw delivered value of non-test users | 4961884.00 | 4961884.00 | true   |
| clean spend rows = raw spend rows                                     | 24.00      | 24.00      | true   |
| clean spend total = raw spend total                                   | 1590000.00 | 1590000.00 | true   |
| step |                         stage                          | order_rows | delivered_rows | delivered_value |
|-----:|--------------------------------------------------------|-----------:|---------------:|----------------:|
| 1    | raw_orders                                             | 5684       | 4949           | 5945268.00      |
| 2    | after removing exact duplicates (O1)                   | 5478       | 4799           | 5741674.00      |
| 3    | after removing test-account orders (U2) = clean_orders | 5193       | 4514           | 4961884.00      |
| step |                      stage                      | user_rows | blank_or_unknown_channel |
|-----:|-------------------------------------------------|----------:|-------------------------:|
| 1    | raw_users                                       | 5135      | 72                       |
| 2    | after removing test accounts (U2) = clean_users | 5100      | 72                       |
