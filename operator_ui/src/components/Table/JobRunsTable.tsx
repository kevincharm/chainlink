import React from 'react'

import classNames from 'classnames'
import { useHistory } from 'react-router-dom'

import { createStyles, withStyles, WithStyles } from '@material-ui/core/styles'
import Table from '@material-ui/core/Table'
import TableBody from '@material-ui/core/TableBody'
import TableCell from '@material-ui/core/TableCell'
import TableRow from '@material-ui/core/TableRow'
import Typography from '@material-ui/core/Typography'

import titleize from 'utils/titleize'
import { TimeAgo } from 'components/TimeAgo'
import { getJobStatusGQL } from 'src/pages/Jobs/utils'

const styles = (theme: any) =>
  createStyles({
    jobRunsCard: {
      overflow: 'auto',
    },
    idCell: {
      width: '40%',
    },
    stampCell: {
      width: '30%',
    },
    statusCell: {
      textAlign: 'end',
      width: '30%',
    },
    runDetails: {
      paddingTop: theme.spacing.unit * 2,
      paddingBottom: theme.spacing.unit * 2,
      paddingLeft: theme.spacing.unit * 2,
    },
    stamp: {
      paddingLeft: theme.spacing.unit,
    },
    status: {
      paddingLeft: theme.spacing.unit * 1.5,
      paddingRight: theme.spacing.unit * 1.5,
      paddingTop: theme.spacing.unit / 2,
      paddingBottom: theme.spacing.unit / 2,
      borderRadius: theme.spacing.unit * 2,
      marginRight: theme.spacing.unit,
      width: 'fit-content',
      display: 'inline-block',
    },
    errored: {
      backgroundColor: theme.palette.error.light,
      color: theme.palette.error.main,
    },
    pending: {
      backgroundColor: theme.palette.listPendingStatus.background,
      color: theme.palette.listPendingStatus.color,
    },
    completed: {
      backgroundColor: theme.palette.listCompletedStatus.background,
      color: theme.palette.listCompletedStatus.color,
    },
    noRuns: {
      padding: theme.spacing.unit * 2,
    },
  })

const classFromStatus = (classes: any, status: string) => {
  if (
    !status ||
    status.startsWith('pending') ||
    status.startsWith('in_progress')
  ) {
    return classes['pending']
  }
  return classes[status.toLowerCase()]
}

export interface Props extends WithStyles<typeof styles> {
  runs: {
    createdAt: string
    id: string
    errors: ReadonlyArray<string>
    finishedAt: string | null
  }[]
}

export const JobRunsTable = withStyles(styles)(({ classes, runs }: Props) => {
  const history = useHistory()

  return (
    <Table padding="none">
      <TableBody>
        {runs.length === 0 && (
          <TableRow>
            <TableCell colSpan={5}>
              <Typography
                variant="body1"
                color="textSecondary"
                className={classes.noRuns}
              >
                No jobs have been run yet
              </Typography>
            </TableCell>
          </TableRow>
        )}

        {runs.length > 0 &&
          runs.map((r) => {
            const status = getJobStatusGQL({
              finishedAt: r.finishedAt,
              errors: r.errors,
            })

            return (
              <TableRow
                key={r.id}
                style={{ cursor: 'pointer' }}
                onClick={() => history.push(`/runs/${r.id}`)}
              >
                <TableCell className={classes.idCell} scope="row">
                  <div className={classes.runDetails}>
                    <Typography variant="h5" color={'primary'} component="span">
                      {r.id}
                    </Typography>
                  </div>
                </TableCell>
                <TableCell className={classes.stampCell}>
                  <Typography
                    variant="body1"
                    color="textSecondary"
                    className={classes.stamp}
                  >
                    Created <TimeAgo tooltip>{r.createdAt}</TimeAgo>
                  </Typography>
                </TableCell>
                <TableCell className={classes.statusCell} scope="row">
                  <Typography
                    variant="body1"
                    className={classNames(
                      classes.status,
                      classFromStatus(classes, status),
                    )}
                  >
                    {titleize(status)}
                  </Typography>
                </TableCell>
              </TableRow>
            )
          })}
      </TableBody>
    </Table>
  )
})
