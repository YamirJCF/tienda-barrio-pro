-- CHECK EXISTING POLICIES FOR SALES
SELECT * FROM pg_policies WHERE tablename = 'sales';
