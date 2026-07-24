bind = '0.0.0.0:8002'
user = 'root'
workers = 1
threads = 2
backlog = 512
chdir = '/www/wwwroot/books.payvandtrans.com'

# РОҲИ НАВ БА ПАПКАИ VENV:
pythonpath = '/www/wwwroot/books.payvandtrans.com/7d8949bcbf85067fceda9f84a6affb6b_venv/lib/python3.12/site-packages'
# Агар дар панел ҷои "Python executable" бошад, инро нишон диҳед:
# daemon = False
# capture_output = True

loglevel = 'info'
worker_class = 'gthread' # gthread барои лоиҳаҳои Django беҳтар аст
errorlog = chdir + '/logs/error.log'
accesslog = chdir + '/logs/access.log'
pidfile = chdir + '/logs/book.pid'

wsgi_app = 'core.wsgi:application'