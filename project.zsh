
package=authd
version=0.2.0

targets=(authd)
type[authd]=crystal
sources[authd]=src/main.cr
depends[authd]="$(ls src/*.cr | grep -v '/main.cr$' | tr '\n' ' ')"


