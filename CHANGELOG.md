## v1.0.0

- initial release

## v1.1.0

- removed referer from allowed restrictions

## v1.1.1

- removed unnecessary dependencies
- support of rails 3+ added

## v1.1.2

- minimum ruby version is now 1.9.3

## v2.0.0

- moved to engine

## v2.0.1

- changed signin IP field to native type for postgres DB

## v2.0.2

- Support for the expiration parameter as a lambda function

## v2.0.3

- Expiration parameter as a lambda function fix

## v2.0.4

- Signins can be created permanent now

## v2.0.5

- bugged. removed

## v2.0.6

- Added IPv6 support
- Signin restrictions as lambda

## v2.0.7

- Compability with Rails 5 migrations

## v2.0.8

- Add ability to skip restriction on token authentication

## v2.0.9

- Add ability to save custom data on signin

## v2.0.11

- replace update_attributes for update in model

## v2.0.12

- _permanent_ and _custom_data_ params in _signin_ method are key-attributes now
- _skip_restrictions_ param in _authenticate_with_token_ method is key-attribute now
- _skip_restrictions_ param in _signout_ method is key-attribute now

## v3.0.0

- Add JWT as intermediate to reduce number of DB requests
