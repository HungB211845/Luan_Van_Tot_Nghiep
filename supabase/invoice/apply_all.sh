#!/bin/bash

# Script to apply all invoice migrations and RPC functions
# Usage: cd supabase/invoice && bash apply_all.sh

set -e  # Exit on error

echo "🚀 Applying Invoice Module Migrations & RPC Functions..."
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Error: Supabase CLI not found. Please install it first.${NC}"
    echo "   Install: npm install -g supabase"
    exit 1
fi

# Function to execute SQL file
execute_sql() {
    local file=$1
    local description=$2

    echo -e "\n${YELLOW}📝 ${description}...${NC}"
    if supabase db execute -f "$file"; then
        echo -e "${GREEN}✅ Success: ${description}${NC}"
    else
        echo -e "${RED}❌ Failed: ${description}${NC}"
        exit 1
    fi
}

# Apply migrations
echo -e "\n${YELLOW}Phase 1: Database Migrations${NC}"
execute_sql "migrations/20251021_create_store_business_info.sql" "Creating store_business_info table"

# Apply RPC functions
echo -e "\n${YELLOW}Phase 2: RPC Functions${NC}"
execute_sql "functions/get_invoice_data.sql" "Creating get_invoice_data RPC function"
execute_sql "functions/get_po_invoice_data.sql" "Creating get_po_invoice_data RPC function"
execute_sql "functions/get_transactions_for_export.sql" "Creating get_transactions_for_export RPC function"

echo -e "\n${GREEN}=================================================="
echo -e "✨ All Invoice Module migrations applied successfully!"
echo -e "==================================================${NC}\n"
