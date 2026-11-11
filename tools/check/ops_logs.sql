select replaceAll(log_attributes['request.path'], '/rest/v1/rpc/', '') rpc, count() n
from logs where source = 'edge_logs' and startsWith(log_attributes['request.path'], '/rest/v1/rpc/')
group by rpc order by n desc limit 30;

select toStartOfHour(timestamp) h, count() n
from logs where source = 'realtime_logs' and positionCaseInsensitive(event_message, 'Unauthorized') > 0
group by h order by h;
