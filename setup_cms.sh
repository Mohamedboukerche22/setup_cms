#!/bin/bash

DB_USER="cmsuser"
DB_NAME="cmsdb"
DB_PASSWORD="cmspassword"
PORT=8889  

echo "🔄 Resetting PostgreSQL database and user..."

# Drop old user and db if exist
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;"

# Create user and db
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

echo "✅ Database and user created."

if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "📦 Activating virtual environment and installing dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Update CMS config file
echo "⚙️ Setting up CMS config..."
cp config/cms.conf.sample config/cms.conf 2>/dev/null
sed -i "s/^user *=.*/user = $DB_USER/" config/cms.conf
sed -i "s/^password *=.*/password = $DB_PASSWORD/" config/cms.conf
sed -i "s/^db *=.*/db = $DB_NAME/" config/cms.conf

if [ ! -f "/usr/local/bin/isolate" ]; then
    echo "🛠️ Building isolate..."
    cd isolate && make && sudo make install && cd ..
fi

echo "🧱 Initializing CMS database..."
cmsInitDB

echo "🚀 Starting CMS Admin Web Server (port $PORT)..."
cmsLogService &
cmsResourceService &
cmsDBService &
cmsAdminWebServer &

sleep 2
echo "🌍 CMS is now running at: http://localhost:$PORT"

echo "✅ Done. Default login: admin / admin"
