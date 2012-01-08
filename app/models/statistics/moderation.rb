class Statistics::Moderation < Statistics::Statistics

  def by_day
    select_all <<-EOS
       SELECT DAYNAME(CONVERT_TZ(created_at,'+00:00','Europe/Paris')) AS d,
              WEEKDAY(CONVERT_TZ(created_at,'+00:00','Europe/Paris')) AS day,
              COUNT(*) AS cnt
         FROM nodes
        WHERE content_type='News'
     GROUP BY d
     ORDER BY day ASC
    EOS
  end

  def average_time
    select_all <<-EOS
       SELECT YEAR(CONVERT_TZ(nodes.created_at,'+00:00','Europe/Paris')) AS year,
              COUNT(*) AS cnt,
              SUM(TIMESTAMPDIFF(SECOND,news.created_at,nodes.created_at)) AS duration,
              MIN(TIMESTAMPDIFF(SECOND,news.created_at,nodes.created_at)) AS min,
              MAX(TIMESTAMPDIFF(SECOND,news.created_at,nodes.created_at)) AS max
         FROM nodes, news
        WHERE nodes.content_id = news.id
          AND nodes.content_type='News'
          AND nodes.created_at >= DATE('2011-01-01 00:00:001')
     ORDER BY year
    EOS
  end

  def top_amr(sql_criterion="")
    select_all <<-EOS
       SELECT login, moderator_id, COUNT(*) AS cnt
         FROM nodes,news,accounts
        WHERE moderator_id IS NOT NULL
          AND content_id=news.id
          AND content_type='News'
          AND moderator_id=accounts.user_id
          #{sql_criterion}
    GROUP BY moderator_id
    ORDER BY LOWER(login) ASC
    EOS
  end

  def top_am
    top_amr "AND (role='moderator' OR role='admin')"
  end

  def top_am_x_days(nbdays)
    select_all <<-EOS
      SELECT login, user_id, cnt
        FROM accounts
   LEFT JOIN (
              SELECT moderator_id, COUNT(*) AS cnt
                FROM nodes
                JOIN news ON nodes.content_id = news.id AND nodes.content_type='News'
               WHERE nodes.created_at >= '#{nbdays.days.ago.to_s :db}'
               GROUP BY moderator_id
             ) AS j ON moderator_id = accounts.user_id
       WHERE (role='moderator' OR role='admin')
    ORDER BY LOWER(login) ASC
    EOS
  end

  def nb_editions_x_days(user_id,nbdays)
    count "SELECT COUNT(*) AS cnt FROM news_versions WHERE user_id=#{user_id} AND created_at >= '#{nbdays.days.ago.to_s :db}'"
  end

  def nb_votes(login)
    $redis.get("users/#{login}/nb_votes").to_i
  end

  def nb_votes_last_month(login)
    $redis.keys("users/#{login}/nb_votes/*").map {|k| $redis.get(k).to_i }.sum
  end

  def moderated_news(nbdays)
    count "SELECT COUNT(*) AS cnt FROM news WHERE (state='published' OR state='refused') AND created_at >= '#{nbdays.days.ago.to_s :db}'"
  end

end
