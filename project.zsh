
package=authd
version=0.2.0

targets=(authd)
type[authd]=crystal
sources[authd]=src/main.cr
depends[authd]="$(ls src/*.cr | grep -v '/main.cr$' | tr '\n' ' ')"

for file in utils/*.cr; do
	util="$(basename ${file%.cr})"
	targets+=($util)
	type[$util]=crystal
	sources[$util]=utils/$util.cr
done

