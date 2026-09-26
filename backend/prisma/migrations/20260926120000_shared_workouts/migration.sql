-- Workouts shared under a code
CREATE TABLE "SharedWorkout" (
    "code" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "items" JSONB NOT NULL,
    "sportSlug" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SharedWorkout_pkey" PRIMARY KEY ("code")
);
CREATE INDEX "SharedWorkout_ownerId_idx" ON "SharedWorkout"("ownerId");
ALTER TABLE "SharedWorkout" ADD CONSTRAINT "SharedWorkout_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "Athlete"("id") ON DELETE CASCADE ON UPDATE CASCADE;
