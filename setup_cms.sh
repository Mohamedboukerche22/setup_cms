#!/bin/bash

# ----------------- CONFIG ------------------
DB_USER="cmsuser"
DB_NAME="cmsdb"
DB_PASSWORD="cmspassword"
CMS_ADMIN_PORT=8889
CMS_WEB_PORT=8888
VENV_DIR="venv"
# -------------------------------------------

echo "📦 Installing CMS from scratch..."

# 🗑️ Remove old PostgreSQL DB and user if they exist
echo "🧹 Cleaning old PostgreSQL database and user..."
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

# ⚙️ Build isolate if not already installed
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

# ✅ All done
echo ""
echo "✅ CMS is installed and running!"
echo "🌐 Admin interface:      http://localhost:$CMS_ADMIN_PORT"
echo "🌐 Contest interface:    http://localhost:$CMS_WEB_PORT"
echo "👤 Default admin login:  admin / admin"
echo "📂 Virtualenv location:  ./$VENV_DIR"
