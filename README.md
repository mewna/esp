# ESP

## Token

```
esp.(userid |> base16).(current time ms |> base16).((userid <> time) |> hmac |> base16)
```

## TODO

- Do something useful with these
```
# connections
[
  %{
    "friend_sync" => false,
    "id" => "136359927",
    "name" => "secretlyanamy",
    "show_activity" => true,
    "type" => "twitch",
    "verified" => true,
    "visibility" => 1
  }
]
    # user
%{
  "avatar" => "a_e9aac0d60feb0323ece1c56fba3f1a5f",
  "discriminator" => "0001",
  "email" => "null@amy.gg",
  "id" => "128316294742147072",
  "locale" => "en-GB",
  "mfa_enabled" => true,
  "username" => "amy",
  "verified" => true
}
```