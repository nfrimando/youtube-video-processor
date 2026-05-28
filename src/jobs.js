import postgres from 'postgres';

const sql = postgres(process.env.DATABASE_URL);

export async function claimJob() {
  const [job] = await sql`
    UPDATE jobs SET status = 'processing', updated_at = now()
    WHERE id = (
      SELECT id FROM jobs
      WHERE status = 'queued'
      ORDER BY created_at
      LIMIT 1
      FOR UPDATE SKIP LOCKED
    )
    RETURNING *
  `;
  return job ?? null;
}

export async function markDone(id, outputPath) {
  await sql`
    UPDATE jobs SET status = 'done', output_path = ${outputPath}, updated_at = now()
    WHERE id = ${id}
  `;
}

export async function markFailed(id, error) {
  await sql`
    UPDATE jobs SET status = 'failed', error = ${error}, updated_at = now()
    WHERE id = ${id}
  `;
}
