#!/bin/bash

# ------------------- CONFIG ----------------------
CMS_VERSION="v1.5.1"
CMS_TARBALL="https://github.com/cms-dev/cms/releases/download/$CMS_VERSION/$CMS_VERSION.tar.gz"
CMS_DIR="cms-$CMS_VERSION"
DB_USER="cmsuser"
DB_NAME="cmsdb"
DB_PASSWORD="cmspassword"
CMS_ADMIN_PORT=8889
CMS_WEB_PORT=8888
VENV_DIR="venv"
# -------------------------------------------------

echo "📦 Downloading CMS $CMS_VERSION..."

# Download and extract CMS
curl -L "$CMS_TARBALL" -o "$CMS_VERSION.tar.gz"
tar -xzf "$CMS_VERSION.tar.gz"
cd "$CMS_DIR" || exit 1

# 🗑️ Remove old PostgreSQL DB and user if they exist
echo "🧹 Resetting PostgreSQL database and user..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null

# 🧱 Create new user and database
echo "🧱 Creating new PostgreSQL user and database..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

# 🐍 Create and activate Python virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv $VENV_DIR
fi

echo "⚙️ Activating virtual environment..."
source $VENV_DIR/bin/activate

# 📥 Install dependencies
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
[ -f dev-requirements.txt ] && pip install -r dev-requirements.txt

# ⚙️ Configure CMS
echo "🧾 Setting up CMS config..."
cp -n config/cms.conf.sample config/cms.conf
cp -n config/cms.ranking.conf.sample config/cms.ranking.conf

sed -i "s/^user *=.*/user = $DB_USER/" config/cms.conf
sed -i "s/^password *=.*/password = $DB_PASSWORD/" config/cms.conf
sed -i "s/^db *=.*/db = $DB_NAME/" config/cms.conf

# ⚙️ Build isolate if not installed
if ! command -v isolate &> /dev/null; then
    echo "🛠️ Building isolate..."
    cd isolate && make && sudo make install && cd ..
fi

# 🧱 Initialize CMS database schema
echo "🧱 Initializing CMS DB schema..."
cmsInitDB

# 🚀 Start all CMS services
echo "🚀 Starting all CMS services..."

cmsLogService & disown
cmsResourceService & disown
cmsDBService & disown
cmsEvaluationService & disown
cmsScoringService & disown
cmsProxyService & disown
cmsAdminWebServer & disown
cmsContestWebServer & disown
cmsRankingWebServer & disown

sleep 2

# ✅ Done
echo ""
echo "✅ CMS $CMS_VERSION is installed and running!"
echo "🌐 Admin interface:      http://localhost:$CMS_ADMIN_PORT"
echo "🌐 Contest interface:    http://localhost:$CMS_WEB_PORT"
echo "👤 Default admin login:  admin / admin"
echo "📂 Virtualenv location:  ./$CMS_DIR/$VENV_DIR"
