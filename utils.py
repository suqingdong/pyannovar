import os
import logging
import ConfigParser

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def safe_open(filename, mode='r'):

    try:
        if mode == 'w':
            dirname = os.path.dirname(filename)
            if dirname and not os.path.exists(dirname):
                os.makedirs(dirname)
        if filename.endswith('.gz'):
            import gzip
            mode += 'b'
            return gzip.open(filename, mode)

        return open(filename, mode)
    except Exception as e:
        get_logger().error('file not exists: {}'.format(filename))
        exit(1)



def get_logger(log_format='[%(asctime)s %(levelname)s] %(message)s', log_level=logging.INFO):

    logging.basicConfig(
        level=log_level, format=log_format, datefmt='%Y-%m-%d %H:%M:%S')

    logger = logging.getLogger(__name__)

    return logger



def get_config(logger, configfile=None):

    print BASE_DIR

    if not configfile:
        if 'NJ' in BASE_DIR:
            configfile = os.path.join(BASE_DIR, 'config_nanjing.ini')
        elif 'TJ' in BASE_DIR:
            configfile = os.path.join(BASE_DIR, 'config_tianjin.ini')
        else:
            configfile =  os.path.join(BASE_DIR, 'config.ini')

    if not os.path.exists(configfile):
        logger.error('config file not exists, please check: {}'.format(configfile))
        exit(1)

    logger.info('use config file: {}'.format(configfile))

    config = ConfigParser.ConfigParser()
    config.read(configfile)

    annovar_dir = config.get('software', 'annovar_dir')
    humandb = config.get('software', 'humandb')

    if not os.path.exists(annovar_dir):
        logger.error('annovar_dir not exists, please check: {}'.format(annovar_dir))
        exit(2)

    if not os.path.exists(humandb):
        logger.error('humandb not exists, please check: {}'.format(humandb))
        exit(2)

    logger.info('find annovar directory: {annovar_dir}'.format(**locals()))
    logger.info('find humandb directory: {humandb}'.format(**locals()))

    return config
