# Введение

# Памятка 

- перейти в бобовую директорию 
- в main должно быть как минимум

```go
package main

import (
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/textproto"
	"net/url"
	"strings"
	"time"
	"flag"
	"fmt"
	"os"
)

var Version = "dev"
```
- стройка (заменить бобовое имя и версию)

```bash
docker buildx build \
  --platform=linux/amd64 \
  --build-arg BIN_NAME=$BEAN_NAME \
  --build-arg VERSION=$BEAN_VERSION \
  -o type=local,dest=./bin \
  .
```

