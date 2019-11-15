
# authd

## Requirements

  * build.zsh
  * [libipc](https://git.karchnu.fr/WeirdOS/libipc)

## Database setup

```sql
create table users(id int, created_at date, updated_at date, username text, realname text, password text, avatar text, perms text[]);
```

## Installation

```sh
build.zsh
```

Add this line to `/etc/ld.so.conf`:

```
sudo echo "/usr/local/lib" >> /etc/ld.so.conf
sudo ldconfig
sudo install -d -m0777 /run/ipc/
```

## Configuration

Create these 3 files:

  * passwd
  * group
  * key

Add something in **key** file, as `mot2passe2ouf!`.

You need then to launch authd:

```
./bin/authd
```

And create some user, for an example, you can use this code (in a **create_\user.cr** file):

```crystal
require "./src/authd.cr"

# Instanciation d'un client authd
a = AuthD::Client.new
a.key = File.read("./key").chomp

pp! u = a.add_user("id", "mdp")
```

and launch it:

```sh
crystal create_user.cr

this will create a user **id** with a **mdp** password.
