#!/bin/sh
set -e

echo "Running Prisma migrations..."
npx prisma migrate deploy
echo "Prisma migrations completed."