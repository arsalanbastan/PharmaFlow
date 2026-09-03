#!/bin/sh
set -e

echo "Running Prisma migrations before application start..."
npx prisma migrate deploy
echo "Prisma migrations completed successfully."
