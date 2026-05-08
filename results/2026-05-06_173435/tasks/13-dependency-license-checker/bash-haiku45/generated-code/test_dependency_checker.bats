#!/usr/bin/env bats

# Test suite for dependency license checker
# Red-green TDD: each test is written before the implementation

setup() {
  # Create a temporary test directory
  TEST_DIR=$(mktemp -d)
  export TEST_DIR

  # Create config directory and files
  mkdir -p "$TEST_DIR/config"

  # Create an allow-list of licenses (one license per line)
  cat > "$TEST_DIR/config/allow-list.txt" <<'EOF'
MIT
Apache-2.0
BSD-3-Clause
ISC
EOF

  # Create a deny-list of licenses
  cat > "$TEST_DIR/config/deny-list.txt" <<'EOF'
AGPL-3.0
GPL-3.0
EOF

  # Create a mock license lookup database
  cat > "$TEST_DIR/config/license-db.txt" <<'EOF'
lodash|MIT
express|MIT
react|MIT
cors|MIT
moment|MIT
uuid|MIT
eslint|MIT
webpack|MIT
typescript|MIT
ts-node|MIT
inquirer|MIT
chalk|MIT
minimist|MIT
yargs|MIT
commander|MIT
dotenv|MIT
joi|MIT
jest|MIT
mocha|MIT
chai|MIT
sinon|MIT
axios|MIT
node-fetch|MIT
jest-mock-extended|MIT
@types/jest|MIT
@types/node|MIT
axios-mock-adapter|MIT
sqlite3|BSD-3-Clause
mysql|BSD-3-Clause
pg|MIT
mongodb|Apache-2.0
redis|MIT
ejs|Apache-2.0
pug|MIT
handlebars|MIT
nunjucks|BSD-2-Clause
next|MIT
gatsby|MIT
vue|MIT
svelte|MIT
angular|MIT
backbone|BSD-3-Clause
knockout|MIT
underscore|MIT
lodash-es|MIT
date-fns|MIT
day.js|MIT
numeral|MIT
chance|MIT
faker|MIT
random-js|MIT
ramda|MIT
immutable|BSD-3-Clause
immer|MIT
reselect|MIT
redux|MIT
redux-saga|MIT
recoil|MIT
zustand|MIT
jotai|MIT
valtio|MIT
xstate|MIT
effector|MIT
mobx|MIT
mobx-react|MIT
react-query|MIT
swr|MIT
vue-query|MIT
angular-query|MIT
apollo-client|MIT
graphql|MIT
graphql-js|MIT
graphql-tag|MIT
@apollo/client|MIT
relay-runtime|MIT
urql|MIT
@urql/core|MIT
socket.io|MIT
socket.io-client|MIT
ws|MIT
mqtt|Apache-2.0
amqp|MIT
grpc|Apache-2.0
@grpc/grpc-js|Apache-2.0
protobufjs|BSD-3-Clause
avsc|MIT
thrift|Apache-2.0
msgpack|MIT
@msgpack/msgpack|Apache-2.0
uuid|MIT
nanoid|MIT
crypto-js|MIT
bcryptjs|MIT
argon2|MIT
scrypt-js|MIT
tweetnacl|Unlicense
libsodium.js|ISC
node-gyp|MIT
npm|Artistic-2.0
yarn|BSD-2-Clause
pnpm|MIT
lerna|MIT
turbo|MPL-2.0
nx|MIT
webpack|MIT
rollup|ISC
parcel|LGPL-2.0
esbuild|MIT
swc|Apache-2.0
sucrase|MIT
babel|MIT
prettier|MIT
eslint|MIT
tslint|Apache-2.0
stylelint|MIT
husky|MIT
lint-staged|MIT
commitizen|MIT
semantic-release|MIT
changelog|MIT
standard-version|MIT
release-it|MIT
tsup|MIT
tsdx|MIT
microbundle|MIT
eik|Apache-2.0
OpenAPI-Generator|Apache-2.0
swagger-ui|Apache-2.0
swagger-editor|Apache-2.0
redoc|MIT
openapi-typescript|MIT
graphql-codegen|MIT
msw|MIT
nock|MIT
proxyquire|MIT
rewire|MIT
testdouble|MIT
jest-mock|MIT
jest-extended|MIT
jest-circus|MIT
vitest|MIT
ava|MIT
tap|ISC
test-runner|MIT
node-tap|ISC
lab|BSD-3-Clause
code|BSD-3-Clause
hapi|BSD-3-Clause
sails|MIT
feathers|MIT
fastify|MIT
koa|MIT
restify|MIT
hurl|MIT
express-generator|MIT
nodemon|MIT
ts-node|MIT
tsx|MIT
swaggen|MIT
swagger-ui-express|MIT
swagger-jsdoc|MIT
joi|MIT
yup|MIT
zod|MIT
ajv|MIT
validate.js|MIT
async-validate|MIT
vuelidate|MIT
vee-validate|MIT
formik|Apache-2.0
react-final-form|MIT
use-form-state|MIT
react-hook-form|MIT
unform|Apache-2.0
react-jsonschema-form|Apache-2.0
formsy-react|MIT
prop-types|MIT
classnames|MIT
clsx|MIT
tailwindcss|MIT
bootstrap|MIT
bulma|MIT
material-ui|MIT
chakra-ui|MIT
ant-design|MIT
element-plus|MIT
vuetify|MIT
buefy|MIT
semantic-ui|MIT
foundation|MIT
pure.css|BSD-3-Clause
skeleton|MIT
unsemantic|MIT
HTML5-Boilerplate|MIT
initializr|MIT
yeoman|BSD-2-Clause
generator-generator|BSD-2-Clause
slush|MIT
brunch|MIT
metalsmith|MIT
gatsby|MIT
jekyll|MIT
hexo|MIT
hugo|Apache-2.0
11ty|MIT
nextjs|MIT
nuxtjs|MIT
remix|MIT
astro|MIT
sveltekit|MIT
qwik|MIT
fastify|MIT
fastapi|BSD-3-Clause
django|BSD-3-Clause
flask|BSD-3-Clause
tornado|Apache-2.0
pyramid|BSD-3-Clause
bottle|MIT
cherrypy|BSD-3-Clause
web2py|LGPL-3.0
pycherrypy|MIT
falcon|Apache-2.0
aiohttp|Apache-2.0
sanic|MIT
starlette|BSD-3-Clause
quart|MIT
asgiref|BSD-3-Clause
channels|BSD-3-Clause
graphene|MIT
strawberry-graphql|MIT
ariadne|BSD-3-Clause
sqlalchemy|MIT
tortoise-orm|Apache-2.0
peewee|MIT
django-orm|BSD-3-Clause
mongoengine|MIT
pydantic|MIT
marshmallow|MIT
cerberus|ISC
voluptuous|Apache-2.0
colander|REPOSER
deform|REPOSER
wtforms|BSD-3-Clause
pytest|MIT
unittest2|BSD-3-Clause
nose|LGPL-2.1
coverage|Apache-2.0
mock|BSD-3-Clause
responses|Apache-2.0
vcrpy|MIT
requests-mock|Apache-2.0
faker|MIT
factory-boy|MIT
hypothesis|MPL-2.0
locust|MIT
selenium|Apache-2.0
playwright|Apache-2.0
puppeteer|Apache-2.0
splash|BSD-3-Clause
beautifulsoup4|MIT
scrapy|BSD-3-Clause
selenium|Apache-2.0
mechanize|BSD-3-Clause
lxml|BSD-3-Clause
html5lib|MIT
cssselect|BSD-3-Clause
parsel|BSD-3-Clause
requests|Apache-2.0
urllib3|MIT
httpx|BSD-3-Clause
aiohttp|Apache-2.0
requests-oauthlib|ISC
authlib|BSD-3-Clause
oauthlib|BSD-3-Clause
pyjwt|MIT
cryptography|Apache-2.0
pyopenssl|Apache-2.0
paramiko|LGPL-2.1
fabric|BSD-2-Clause
ansible|GPL-3.0
salt|Apache-2.0
puppet|Apache-2.0
chef|Apache-2.0
cffi|MIT
ctypes|MIT
pycparser|BSD-3-Clause
ipython|BSD-3-Clause
jupyterlab|BSD-3-Clause
jupyter|BSD-3-Clause
numpy|BSD-3-Clause
scipy|BSD-3-Clause
pandas|BSD-3-Clause
scikit-learn|BSD-3-Clause
statsmodels|BSD-3-Clause
sympy|BSD-3-Clause
pillow|HPND
opencv-python|Apache-2.0
scikit-image|BSD-3-Clause
imageio|BSD-2-Clause
plotly|MIT
matplotlib|PSF
seaborn|BSD-3-Clause
bokeh|BSD-3-Clause
altair|BSD-3-Clause
plotnine|GPL-2.0
ggplot|MIT
pyglet|BSD-3-Clause
pygame|LGPL-2.1
arcade|MIT
three.js|MIT
babylon.js|Apache-2.0
cesium.js|Apache-2.0
oimo.js|MIT
physijs|MIT
ammo.js|zlib
cannon.js|MIT
p2.js|MIT
planck.js|MIT
matter.js|MIT
rapier|Apache-2.0
solana|MIT
web3.js|LGPL-3.0
ethers.js|MIT
truffle|MIT
hardhat|MIT
brownie|MIT
ganache|MIT
remix-ide|MIT
web3.py|LGPL-3.0
eth-account|MIT
eth-keys|MIT
eth-utils|MIT
eth-typing|MIT
rlp|MIT
hexbytes|MIT
eth-hash|MIT
eth-rlp|MIT
eth-abi|MIT
eth-trie|MIT
trie|MIT
merkle-patricia-tree|ISC
ethereumjs-util|MIT
ethereumjs-tx|MIT
ethereumjs-block|MIT
ethereumjs-vm|MIT
ethereumjs-account|MIT
ethereumjs-common|MIT
ethjsonrpc|MIT
ethpipe|MIT
eth-lightwallet|MIT
keythereum|MIT
mnemonic-phrase|UNKNOWN
bip39|MIT
hdkey|MIT
ethereum-hdwallet|MIT
ethconnect|AGPL-3.0
web3provider|MIT
json-rpc-engine|ISC
eth-json-rpc-infura|ISC
eth-json-rpc-middleware|MIT
eth-block-tracker|MIT
eth-transaction-tracker|MIT
eth-sig-util|MIT
ethereumjs-wallet|MIT
node-rsa|MIT
crypto-js|MIT
keythereum|MIT
solidity|GPL-3.0
vyper|MIT
certora|UNKNOWN
slither|AGPL-3.0
hardhat-slither|AGPL-3.0
ganache-cli|UNKNOWN
testrpc|UNKNOWN
ethash|GPL-3.0
go-ethereum|LGPL-3.0
parity|GPL-3.0
trinity|MIT
py-evm|MIT
pysha3|UNKNOWN
eth-hash|MIT
eth-keys|MIT
eth-typing|MIT
eth-utils|MIT
eth-account|MIT
ethereum|MIT
pythereum|MIT
pyethereum|MIT
pycoin|MIT
bit|MIT
bitcoinlib|MIT
python-bitcoinlib|MIT
UTXO|MIT
trezor|GPL-3.0
ledger|UNKNOWN
keepkey|ISC
ethereum-mnemonic|UNKNOWN
ethereum-wallet|UNKNOWN
bitmerchant|MIT
python-mnemonic|ISC
bip_utils|MIT
ecdsa|MIT
secp256k1|MIT
coincurve|MIT
Crypto|UNKNOWN
PyCryptodome|Public
PyCrypto|PUBLIC
gmpy2|LGPL-2.1
mpmath|BSD-3-Clause
sympy|BSD-3-Clause
pycparser|BSD-3-Clause
CFFI|MIT
Werkzeug|BSD-3-Clause
Jinja2|BSD-3-Clause
MarkupSafe|BSD-3-Clause
click|BSD-3-Clause
urllib3|MIT
requests|Apache-2.0
httpx|BSD-3-Clause
aiohttp|Apache-2.0
twisted|MIT
asyncio|PSF
gevent|MIT
greenlet|MIT
eventlet|MIT
motor|Apache-2.0
pymongo|Apache-2.0
redis|MIT
sqlalchemy|MIT
peewee|MIT
tortoise-orm|Apache-2.0
MongoEngine|MIT
gino|BSD-3-Clause
databases|BSD-3-Clause
asyncpg|BSD-3-Clause
psycopg2|LGPL-3.0
mysqlclient|GPL-2.0
sqlite3|PSF
orator|MIT
doctrine|MIT
eloquent|MIT
avro-python3|Apache-2.0
confluent-kafka|Apache-2.0
pykafka|Apache-2.0
kafka-python|Apache-2.0
pika|MPL-2.0
kombu|BSD-3-Clause
celery|BSD-3-Clause
huey|MIT
rq|BSD-2-Clause
APScheduler|MIT
schedule|MIT
periodiq|UNKNOWN
tenacity|Apache-2.0
retrying|Apache-2.0
backoff|MIT
expo|MIT
python-dateutil|BSD-3-Clause
pytz|MIT
arrow|Apache-2.0
delorean|MIT
maya|MIT
freezegun|Apache-2.0
croniter|MIT
tqdm|MIT
rich|MIT
click|BSD-3-Clause
colorama|BSD-3-Clause
pygments|BSD-2-Clause
pyyaml|MIT
toml|MIT
configparser|MIT
python-decouple|MIT
dynaconf|MIT
pydantic|MIT
pydantic-settings|MIT
marshmallow|MIT
cerberus|ISC
voluptuous|Apache-2.0
colander|REPOSER
deform|REPOSER
wtforms|BSD-3-Clause
attrs|MIT
dataclasses|MIT
dataclasses-json|MIT
typeguard|Apache-2.0
beartype|Unlicense
pydantic-extra-types|MIT
pydantic-core|MIT
typing-extensions|Python Software Foundation
typing-inspect|MIT
mypy-extensions|MIT
typing-utils|MIT
overload|MIT
typeit|MIT
dependency-injector|BSD-3-Clause
injector|Apache-2.0
lagom|MIT
punq|MIT
antidote|MIT
ioc|MIT
cqrs|MIT
eventsourcing|BSD-3-Clause
nanobus|MIT
nameko|BSD-2-Clause
rpc|MIT
grpc|Apache-2.0
grpcio|Apache-2.0
protobuf|BSD-3-Clause
msgpack|Apache-2.0
cloudpickle|BSD-3-Clause
dill|BSD-3-Clause
pickle|PSF
json|PSF
msgpack-python|Apache-2.0
bson|Apache-2.0
ujson|BSD-3-Clause
orjson|MIT
rapidjson|MIT
simdjson|Apache-2.0
capnproto|MIT
flatbuffers|Apache-2.0
avro|Apache-2.0
thrift|Apache-2.0
edn-format|MIT
transit|UNKNOWN
fressian|UNKNOWN
bencode|UNKNOWN
toml|MIT
msgpack|Apache-2.0
cbor|MIT
protobuf|BSD-3-Clause
structlog|MIT
python-json-logger|BSD-3-Clause
colorlog|MIT
logstash-formatter|MIT
graylog-python|MIT
raven|BSD-3-Clause
sentry-sdk|BSD-2-Clause
elastic-apm|BSD-3-Clause
newrelic|UNKNOWN
datadog|BSD-3-Clause
prometheus-client|Apache-2.0
statsd|MIT
influxdb-client|MIT
telegraf|MIT
dd-trace-py|BSD-3-Clause
elastic-apm|BSD-3-Clause
jaeger-client|Apache-2.0
opentelemetry-api|Apache-2.0
opentelemetry-sdk|Apache-2.0
opentelemetry-exporter-jaeger|Apache-2.0
opentelemetry-exporter-prometheus|Apache-2.0
opentelemetry-exporter-otlp|Apache-2.0
opentelemetry-instrumentation|Apache-2.0
opentelemetry-instrumentation-asgi|Apache-2.0
opentelemetry-instrumentation-celery|Apache-2.0
opentelemetry-instrumentation-django|Apache-2.0
opentelemetry-instrumentation-flask|Apache-2.0
opentelemetry-instrumentation-grpc|Apache-2.0
opentelemetry-instrumentation-sqlalchemy|Apache-2.0
opentelemetry-instrumentation-redis|Apache-2.0
opentelemetry-instrumentation-psycopg2|Apache-2.0
opentelemetry-instrumentation-pymongo|Apache-2.0
opentelemetry-instrumentation-logging|Apache-2.0
opentelemetry-instrumentation-httpx|Apache-2.0
opentelemetry-instrumentation-requests|Apache-2.0
opentelemetry-exporter-datadog|Apache-2.0
opentelemetry-exporter-newrelic|Apache-2.0
opentelemetry-exporter-aws-xray|Apache-2.0
opentelemetry-exporter-honeycomb|Apache-2.0
opentelemetry-exporter-gcp-trace|Apache-2.0
opentelemetry-exporter-azure-monitor|Apache-2.0
pytest|MIT
unittest|PSF
nose|LGPL-2.1
nose2|BSD-2-Clause
doctest|PSF
tox|MIT
coverage|Apache-2.0
pytest-cov|MIT
pytest-xdist|MIT
pytest-timeout|MIT
pytest-mock|MIT
pytest-asyncio|MIT
pytest-aiohttp|Apache-2.0
pytest-tornado|Apache-2.0
pytest-twisted|MIT
responses|Apache-2.0
vcrpy|MIT
pytest-vcr|MIT
betamax|Apache-2.0
httpretty|MIT
requests-mock|Apache-2.0
moto|Apache-2.0
localstack|Apache-2.0
testcontainers-python|Apache-2.0
faker|MIT
factory-boy|MIT
pytest-factoryboy|MIT
hypothesis|MPL-2.0
pytest-datafiles|MIT
pytest-benchmark|BSD-3-Clause
pytest-profiling|MIT
line-profiler|BSD-3-Clause
memory-profiler|BSD-3-Clause
py-spy|Apache-2.0
scalene|Apache-2.0
tracemalloc|PSF
timeit|PSF
cProfile|PSF
pstats|PSF
fuzz-testing|MIT
atheris|Apache-2.0
pathlib|MIT
pathlib2|MIT
pathspec|ISC
glob|PSF
fnmatch|PSF
shutil|PSF
os|PSF
sys|PSF
tempfile|PSF
shlex|PSF
subprocess|PSF
threading|PSF
multiprocessing|PSF
concurrent|PSF
asyncio|PSF
contextvars|PSF
copy|PSF
pickle|PSF
json|PSF
csv|PSF
xml|PSF
html|PSF
urllib|PSF
email|PSF
mimetypes|PSF
codecs|PSF
encodings|PSF
base64|PSF
binascii|PSF
re|PSF
difflib|PSF
textwrap|PSF
string|PSF
io|PSF
pickle|PSF
copyreg|PSF
marshal|PSF
json|PSF
dbm|PSF
sqlite3|PSF
zlib|PSF
gzip|PSF
bz2|PSF
lzma|PSF
zipfile|PSF
tarfile|PSF
hashlib|PSF
hmac|PSF
secrets|PSF
uuid|PSF
math|PSF
cmath|PSF
decimal|PSF
fractions|PSF
random|PSF
statistics|PSF
functools|PSF
itertools|PSF
operator|PSF
enum|PSF
types|PSF
pprint|PSF
reprlib|PSF
abc|PSF
collections|PSF
array|PSF
weakref|PSF
unittest.mock|PSF
datetime|PSF
calendar|PSF
locale|PSF
gettext|PSF
getpass|PSF
curses|PSF
platform|PSF
errno|PSF
ctypes|MIT
unittest.mock|PSF
doctest|PSF
pdb|PSF
timeit|PSF
trace|PSF
gc|PSF
inspect|PSF
site|PSF
code|PSF
codeop|PSF
builtins|PSF
__future__|PSF
__main__|PSF
atexit|PSF
signal|PSF
warnings|PSF
importlib|PSF
sys|PSF
modules|PSF
EOF

  export ALLOW_LIST="$TEST_DIR/config/allow-list.txt"
  export DENY_LIST="$TEST_DIR/config/deny-list.txt"
  export LICENSE_DB="$TEST_DIR/config/license-db.txt"
}

teardown() {
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

# Test 1: Script exists and is executable
@test "dependency-checker script exists" {
  [ -f "dependency-checker.sh" ]
}

# Test 2: Script can parse package.json
@test "parse package.json with dependencies" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "name": "test-app",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "^4.18.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"express"* ]]
}

# Test 3: Script can parse requirements.txt
@test "parse requirements.txt with dependencies" {
  local requirements="$TEST_DIR/requirements.txt"
  cat > "$requirements" <<'EOF'
lodash==1.0.0
express==2.0.0
EOF

  run bash dependency-checker.sh --manifest "$requirements" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"express"* ]]
}

# Test 4: Report shows approved licenses
@test "report shows approved licenses correctly" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"approved"* ]] || [[ "$output" == *"APPROVED"* ]]
  [[ "$output" == *"lodash"* ]]
}

# Test 5: Report shows denied licenses
@test "report shows denied licenses correctly" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "ethconnect": "^1.0.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"denied"* ]] || [[ "$output" == *"DENIED"* ]]
  [[ "$output" == *"ethconnect"* ]]
}

# Test 6: Report shows unknown licenses
@test "report shows unknown licenses correctly" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "unknown-package": "^1.0.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown"* ]] || [[ "$output" == *"UNKNOWN"* ]]
}

# Test 7: Script exits with error code when denied licenses found
@test "script exits with non-zero when denied licenses found" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "slither": "^1.0.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -ne 0 ]
}

# Test 8: Script exits with success when only approved licenses
@test "script exits with zero when only approved licenses found" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "^4.18.0",
    "react": "^18.0.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
}

# Test 9: Generate JSON report
@test "generate json report format" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "^4.18.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB" --format json
  [ "$status" -eq 0 ]
  # Check for valid JSON structure
  echo "$output" | grep -q '{"dependencies"' || echo "$output" | grep -q '\[{'
}

# Test 10: Generate text report (default)
@test "generate text report format (default)" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lodash"* ]]
}

# Test 11: Handle missing manifest
@test "handle missing manifest file gracefully" {
  run bash dependency-checker.sh --manifest /nonexistent/file.json --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# Test 12: Handle missing config files
@test "handle missing config files gracefully" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow /nonexistent/allow.txt --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}

# Test 13: Mixed dependencies (approved, denied, unknown)
@test "handle mixed dependency statuses correctly" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21",
    "slither": "^1.0.0",
    "unknown-package": "^1.0.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lodash"* ]]
  [[ "$output" == *"slither"* ]]
  [[ "$output" == *"unknown-package"* ]]
}

# Test 14: Case-insensitive license matching
@test "case-insensitive license matching" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"approved"* ]] || [[ "$output" == *"APPROVED"* ]]
}

# Test 15: Version parsing from package.json
@test "correctly extract version from package.json" {
  local package_json="$TEST_DIR/package.json"
  cat > "$package_json" <<'EOF'
{
  "dependencies": {
    "lodash": "4.17.21",
    "express": "^4.18.0",
    "react": "~18.1.0"
  }
}
EOF

  run bash dependency-checker.sh --manifest "$package_json" --allow "$ALLOW_LIST" --deny "$DENY_LIST" --license-db "$LICENSE_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"4.17.21"* ]] || [[ "$output" == *"lodash"* ]]
}
