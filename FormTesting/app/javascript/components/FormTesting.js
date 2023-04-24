import React, { useState, useEffect } from "react";
import ContentLoader from "react-content-loader";
import Skeleton from 'react-loading-skeleton'
import ArrowRightAltIcon from '@mui/icons-material/ArrowRightAlt';
import CircularProgress from '@mui/material/CircularProgress';
import HighlightOffIcon from '@mui/icons-material/HighlightOff';
import { Dialog, DialogTitle, DialogContent, DialogContentText, DialogActions } from '@material-ui/core';
import ProgressBar from 'react-progress-bar-plus';
import 'react-progress-bar-plus/lib/progress-bar.css';
import axios from "axios";
import CancelIcon from '@mui/icons-material/Cancel';
import ArrowLeftIcon from '@mui/icons-material/ArrowLeft';
import ArrowRightIcon from '@mui/icons-material/ArrowRight';
import KeyboardArrowLeftIcon from "@mui/icons-material/KeyboardArrowLeft";
import KeyboardArrowRightIcon from "@mui/icons-material/KeyboardArrowRight";
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import CircleOutlinedIcon from '@mui/icons-material/CircleOutlined';
import Button from "@material-ui/core/Button";
import TextField from "@material-ui/core/TextField";
import { Avatar, List, ListItem, Card, CardContent, IconButton, Typography, makeStyles, Modal, Collapse } from "@material-ui/core";
import { CheckIcon, CloseIcon, ExpandLess, ExpandMore, KeyboardArrowDown, KeyboardArrowLeft, KeyboardArrowRight, ExpandMoreOutlined, CheckCircle } from "@material-ui/icons";
import { useTheme } from '@material-ui/core/styles';
import { Chip, Stepper, Step, StepLabel } from '@material-ui/core';
const useStyles = makeStyles((theme) => ({
	card: {
		marginTop: 8,
		maxWidth: '1600px',
		minWidth: '60vw',
		backgroundColor: theme.palette.background.paper,
		//border: '0.1px solid #000',
		boxShadow: theme.shadows[1],
	},
	card2: {
		backgroundColor: theme.palette.background.paper, 
		boxShadow: theme.shadows[1],
	},
	card3: {
		padding: '-8px',
	},
	image: {
		width: '150px',
		height: '60px',
		border: '0.4px solid grey',
		transition: 'opacity 0.3s, box-shadow 0.3s', 
		'&:hover': {
			opacity: 0.7,
			boxShadow: '0px 0px 10px 2px rgba(0, 0, 0, 0.3)',
		},
	},
	image2: {
		width: '90px',
		height: '40px',

		transition: 'opacity 0.3s, box-shadow 0.3s', 
		'&:hover': {
			opacity: 0.7,
			boxShadow: '0px 0px 10px 2px rgba(0, 0, 0, 0.3)',
		},
	},
	element: {
		display: 'flex',
		flexDirection: 'row',
		alignItems: 'center',
	},
	modal: {
		display: 'flex',
		alignItems: 'center',
		justifyContent: 'center',
	},
	paper: {
		backgroundColor: theme.palette.background.paper,
	},
	iconButton: {
		position: 'absolute',
		right: theme.spacing(1),
		top: theme.spacing(1),
	},
	"@media screen and (max-width: 1600px)": {
		card: {
			minWidth: '90vw',
		},
	},
}));

function Progress(){
	return (
		<CircularProgress size={25}/>
	)
}

const SearchBox = () => {
	const [loading, setLoading] = useState(false);
	const classes = useStyles();
	const theme = useTheme();
	const [url, setUrl] = useState("");
	const [result, setResult] = useState(null);
	const [openSheet, setOpenSheet] = useState(-1);
	const [openSubSheet, setOpenSubSheet] = useState(-1);
	const [openSampleSubSheet, setOpenSampleSubSheet] = useState(-1);	
	const [openFormURLSubSheet, setOpenFormURLSubSheet] = useState(-1);
	const [open, setOpen] = useState(false);
	const [imgOpen, setImgOpen] = useState(false);
	const [imgIndex, setImgIndex] = useState(null);
const [completedSteps, setCompletedSteps] = useState([]);
	const [formData, setFormData] = useState({});
	const [imageSrc, setImageSrc] = useState(null);
	const [isToggleOn, setIsToggleOn] = useState(false);
	const [imgDIndex, setImgDIndex] = useState(0);
	const [isBefore, setIsBefore] = useState(false);
	const [activeStep, setActiveStep] = useState(0);
	const [isLoading, setIsLoading] = useState(false);
	const [activeStepProgress, setActiveStepProgress] = useState(0);
	const blankImageSource = "https://us.123rf.com/450wm/yehorlisnyi/yehorlisnyi2104/yehorlisnyi210400016/167492439-no-photo-or-blank-image-icon-loading-images-or-missing-image-mark-image-not-available-or-image.jpg?ver=6"

	useEffect(() => {
  let progress = 0;
  const interval = setInterval(() => {
    progress += Math.random() * 10;
    if (progress > 100) {
      progress = 100;
    }
    setActiveStepProgress(progress);
  }, 500);
  return () => clearInterval(interval);
	}, [activeStep, activeStepProgress]);

	useEffect(() => {
		if (activeStepProgress === 100) {
			setCompletedSteps((prevCompletedSteps) => [...prevCompletedSteps, activeStep]);
		}
	}, [activeStep, activeStepProgress]);

	useEffect(() => {
		if (isLoading) {
			const timer = setTimeout(() => {
				setActiveStep((prevActiveStep) => prevActiveStep + 1);
				setIsLoading(false);
			}, 9000);
			return () => clearTimeout(timer);
		}
	}, [isLoading]);

	useEffect(() => { 
		const timer = setTimeout(() => {
			setIsLoading(true);
		}, 2000);
		return () => clearTimeout(timer);
	}, [activeStep]);

	const handleToggleClick = (i) => {
		setIsToggleOn(!isToggleOn);
		setImgDIndex((i+1)%2);
	};

	const handleClickImgOpen = (index,is_Before) => {
		setImgOpen(true);
		setImgIndex(index);
		setImgDIndex(is_Before);
		setIsToggleOn(is_Before);
	};

	const handleImgClose = () => {
		setImgOpen(false);
		setImgIndex(null);
	};
	

	const handleSubmit = async () => {
		if (url) {
			try {
				setCompletedSteps([]);
				setActiveStep(0);
				setLoading(true);
				//setIsLoading(true);
				const token =
					document.querySelector('[name=csrf-token]').content
				axios.defaults.headers.common['X-CSRF-TOKEN'] = token

				const response = await axios.post("/search", { url }, {
					onUploadProgress: (progressEvent) => {
						const percentage = Math.round(
							(progressEvent.loaded * 100) / progressEvent.total
						);
					},
				});
				setCompletedSteps([]);
				setActiveStep(0);
				setLoading(false);
				setIsLoading(false);
				console.log(response.data);
				setResult(response.data);
			} catch (error) {
				setActiveStep(0);
				setCompletedSteps([]);
				setLoading(false);
				setIsLoading(false);
				console.error(error);
			}
		}
	};

	const handleOpen = (formData) => {
		setFormData(formData);
		setOpen(true);
	};

	const handleClose = () => {
		setOpen(false);
	};

	const getStepIcon = (value) => {
		if (value==1) {
			return <CheckCircleIcon style={{ marginLeft: '2px', color: 'green' }} />;
		}
		else if (value==0){
			return <CancelIcon style={{ marginLeft: '2px', color: 'red' }} />;
		}
		else
			return <CancelIcon style={{ marginLeft: '2px', color: 'red' }} />;
	};

	const getStepStatus = (value) => {
		if (value) {
			return 'completed';
		}
		return 'error';
	};
	const [openTitleImage, setOpenTitleImage] = useState(false);
	const [selectedTitleImageIndex, setSelectedTitleImageIndex] = useState(0);
	const handleClickOpenTitleImage = (index) => {
		setSelectedTitleImageIndex(index);
		setOpenTitleImage(true);
	};

	const handleCloseTitleImage = () => {
		setOpenTitleImage(false);
	};

	const steps = ['Fetching Forms', 'Validating Fields', 'Submitting Forms', 'Taking Screenshots', 'Validating Screenshots'];

	return (
		<div style={{ padding: '15px', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
		<div style={{ maxWidth: 'fit-content', minWidth: '25vw', marginBottom:'15px', display: 'flex', justifyContent: 'center' }}>
		<TextField
		label="Enter URL"
		value={url}
		onChange={(event) => setUrl(event.target.value)}
		style={{ minWidth: '30vw', marginRight: '15px' }}
		/>
		<Button
		variant="contained"
		color="primary"
		disabled={loading}
		onClick={handleSubmit}
		sx={{ position: 'relative', 
				'& span': {
					padding: '10px',
				},
		}}
		>
		Submit	
		</Button>

		</div>

		<div>
		{result && result.mapResult[0].hasOwnProperty('pluginrequesterror') && (
			<div>
			<Typography variant="body2" component="p" style={{ fontWeight: 'bold' }}>
			{result.mapResult[0].pluginrequesterror}
			</Typography>
			</div>
		)}
		{loading ? (
				<div>
				<Stepper activeStep={activeStep} orientation="vertical">
				{steps.map((label, index) => {
					return (
						<Step key={label}>	
							{activeStep == index ? <StepLabel StepIconComponent={Progress}>{label}</StepLabel> : <StepLabel>{label}</StepLabel>}	
						</Step>
					);
				})}
				</Stepper>
				</div>
			) :
				(result && !result.mapResult[0].hasOwnProperty('pluginrequesterror') && 
					result.mapResult.map((values, i) => (
						//Object.entries(data).map(([formId, values], i) => (
							<Card className={classes.card} key={i}>
							<CardContent>
							<div style={{ display: 'flex', alignItems: 'center', position: 'relative' }}>
							<div style={{ width: '40px', textAlign: 'center', fontWeight: 'bold', color: 'black' }}>
							{i + 1}
							</div>
							<div style={{ flex: 1, borderLeft: '3px solid black', paddingLeft: '10px' }}>
							<div className={classes.element} style={{ marginLeft: '10px', display: 'flex', justifyContent: 'space-between'}}>
							<div style={{ display: 'flex', alignItems: 'center' }}>
							{values.screenshotdataaftersubmission && values.screenshotdataaftersubmission[0]?.screenshot_before ?
								<img
								src={decodeBase64Image(values.screenshotdataaftersubmission[0].screenshot_before)}
								alt={`Screenshot`}
								style={{ width: '90px', height: '40px' }}
								className={classes.image2}
								onClick={() => handleClickOpenTitleImage(i)}
								/>
								:
								<img
								src={blankImageSource}
								alt={`Blank`}
								style={{ width: '90px', height: '40px' }}
								className={classes.image2}
								/>
							}

							<Typography variant="body2" component="p" style={{ fontWeight: 'bold', marginLeft: '5px' }}>
							{values.formname} #{values.formid}
							</Typography> 
							</div>
							<Dialog 
							open={openTitleImage && selectedTitleImageIndex === i} 
							onClose={handleCloseTitleImage}
							fullWidth
							maxWidth="sm"
							PaperProps={{
								style: {
									overflowX: "hidden",
										minWidth: "fit-content",
								},
							}}
							>	

							<DialogActions style={{background:'aliceblue'}}>
							<div style={{display:'flex', alignItems: 'center', width:'100%'}}>
							<Typography variant="body2" component = "p" style={{ fontWeight: 'bold', color: 'black', marginLeft: '0' }}>
							Screenshot	
							</Typography>
							<HighlightOffIcon onClick={handleCloseTitleImage} style={{ marginLeft: '2px', color: 'black', marginLeft: 'auto' }} />
							</div>
							</DialogActions>
							<DialogContent>
							<DialogContentText>
							<div>
							{values.screenshotdataaftersubmission && values.screenshotdataaftersubmission[0]?.screenshot_before ?
								<img src={decodeBase64Image(values.screenshotdataaftersubmission[0].screenshot_before)} alt={"Screenshot"} />
								:
								<img src={blankImageSource} alt={"Blank"} />
							}
							</div>
							</DialogContentText>
							</DialogContent>
							</Dialog>
							<div style={{ display: 'flex', alignItems: 'center', background: values.formvalidated ? '#EBFAEE' : '#FFE0DF', borderRadius: '10px', padding: '10px' }}>
							<div style={{ width: '20px' }} />
							<Typography variant="body2" component="p" style={{ fontWeight: 'bold', color: values.formvalidated ? 'black' : 'black', display: 'flex', alignItems: 'center' }}>
							Form Testing:{values.formvalidated ? <CheckCircleIcon style={{ marginLeft: '10px', color: 'green' }} /> : <CancelIcon style={{ marginLeft: '10px', color: 'red' }} />}
							</Typography>
							</div>
							</div>
							</div>
							<IconButton
							onClick={() => { 
								if(openSheet === i) {
									setOpenSheet(-1);
								}
								else{
									setOpenSheet(i);
									setOpenFormURLSubSheet(i);
								}
							}}
							>
							{openSheet === i ? <ExpandLess /> : <ExpandMore />}
							</IconButton>
							</div>
							<Collapse in={openSheet === i} timeout="auto" unmountOnExit>
							<div style={{ positon: 'relative', display:'flex'}}>
							<div style={{ padding: '15px', backgroundColor: 'white', marginRight: '10px' }}>
							<Typography variant="body2" component="p" >
							<span style={{ fontWeight: 'bold' }}>Form ID: </span>
							{values.formid}
							</Typography>
							<Typography variant="body2" component="p" style={{ marginTop: '10px' }}>
							<span style={{ fontWeight: 'bold' }}>Form Name: </span> 
							{values.formname}
							</Typography>
							<Typography variant="body2" component="p" style={{ marginTop: '10px' }}>
							<span style={{ fontWeight: 'bold' }}>Form Type: </span> 
							{values.formtype}
							</Typography>



							<div style={{ display: 'flex', alignItems: 'flexStart', flexDirection: 'column', marginTop:'10px'}}>
							<Typography variant="body2" component="p" style={{ fontWeight: 'bold' }}>Form Fields ({values.formfieldcount})</Typography>
							<div style={{ display: 'flex', flexWrap: 'wrap', marginTop: '5px', alignItems: 'center', alignContent: 'end', gap: '4px' }}>
							{values.samplevalues.map((field, fieldIndex) => (
								field.type !== 'hidden' && (
									<Chip label={field.name} variant="outlined" />
								)
							))}	
							</div>
							</div>



							<div style={{ marginRight: 'auto', display:'flex', flexDirection:'column' }}>
							<div style={{ marginBottom: 'auto', display:'flex', flexDirection:'column' }}>
							<div style={{ display: 'flex', alignItems: 'center'}}>
							<Typography variant="body2" component="p" style={{ fontWeight: 'bold' }}>Sample Values</Typography>
							<IconButton	
							onClick={() =>
								openSampleSubSheet === i ? setOpenSampleSubSheet(-1) : setOpenSampleSubSheet(i)}
							>
							{openSampleSubSheet === i ? <ExpandLess /> : <ExpandMore />}
							</IconButton>
							</div>
							<Collapse in={openSampleSubSheet === i} timeout="auto" unmountOnExit>
							<Card className={classes.card2}>
							<CardContent>
							<div style={{ display: 'flex', width: 'auto', height: 'auto', padding: '0px' }}>
							<List component="nav" className={classes.card3} style={{ justifyContent: 'flex-end' }}>
							{values.samplevalues.map((field, fieldIndex) => (
								field.type!='hidden' && (
									<ListItem key={fieldIndex}>
									<Typography variant="body3">
									<span style={{ fontWeight: 'bold', marginRight: '3px' }}>{field.name}:</span>
									{field.type === 'date' ? 'Sample date' : field.value}
									</Typography>
									</ListItem>
								)
							))}
							</List>
							</div>
							</CardContent>
							</Card>
							</Collapse>
							</div>
							</div>




							<div style={{ display: 'flex', alignItems: 'center', marginTop: '20px' }}>	
							<div style={{ display: 'flex', justifyContent: 'center', background: 'aliceblue', borderRadius: '10px' }}>
							<Stepper alternativeLabel style={{ background: 'aliceblue', borderRadius: '10px' }}>

							<Step key={'Fields Validated'} completed={values.fieldsvalidated}>
							<StepLabel error={!values.fieldsvalidated} StepIconComponent={() => getStepIcon(values.fieldsvalidated?1:0)}>
							<Typography variant="body2" component="p" style={{ marginLeft: '10px', display: 'flex', alignItems: 'center' }}>
							<span style={{ fontWeight: 'bold', marginRight: '2px' }}>Fields Validated</span>
							</Typography>
							</StepLabel>
							</Step>

							<Step key={'Form Submitted'} completed={values.formsubmitted}>
							<StepLabel error={!values.formsubmitted} StepIconComponent={() => getStepIcon(!values.fieldsvalidated?2:(values.formsubmitted?1:0))}>
							<Typography variant="body2" component="p" style={{ marginLeft: '10px', display: 'flex', alignItems: 'center' }}>
							<span style={{ fontWeight: 'bold', marginRight: '2px' }}>Form Submitted</span>
							</Typography>
							</StepLabel>
							</Step>

							<Step key={'Screenshots Validated'} completed={values.screenshotsvalidated}>
							<StepLabel error={!values.screenshotsvalidated} StepIconComponent={() => getStepIcon(!values.formsubmitted?2:(values.screenshotsvalidated?1:0))}>
							<Typography variant="body2" component="p" style={{ marginLeft: '10px', display: 'flex', alignItems: 'center' }}>
							<span style={{ fontWeight: 'bold', marginRight: '2px' }}>Screenshots Validated</span>
							</Typography>
							</StepLabel>
							</Step>

							</Stepper>
							</div>
							</div>

							{!values.formvalidated && (
								<div style={{ display: 'flex', alignItems: 'center', marginTop: '10px' }}>
								<div style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'black', marginRight: '5px' }} />
								<Typography variant="body2" component="p" style={{ marginLeft: '10px', display: 'flex', alignItems: 'center' }}>
								<span style={{ fontWeight: 'bold', marginRight: '3px' }}>Error: </span>
								<span style={{ color: 'red', fontWeight: 'bold' }}>{values.formvalidationerror}</span>
								</Typography>
								</div>	
							)}
							</div>



							<div style={{ marginLeft: 'auto', marginBottom: 'auto', display:'flex', flexDirection:'column' }}>
							<div style={{ marginLeft: 'auto', marginBottom: 'auto', display:'flex', flexDirection:'column' }}>
							<div style={{ display: 'flex', alignItems: 'center', marginLeft:'auto' }}>
							<Typography variant="body2" component="p">
							<span style={{ fontWeight: 'bold' }}>Form URL(s): </span>
							</Typography>	
							<IconButton	
							onClick={() =>
								openFormURLSubSheet === i ? setOpenFormURLSubSheet(-1) : setOpenFormURLSubSheet(i)}
							>
							{openFormURLSubSheet === i ? <ExpandLess /> : <ExpandMore />}
							</IconButton>
							</div>	
							<Collapse in={openFormURLSubSheet === i} timeout="auto" unmountOnExit>
							<Card className={classes.card2}>
							<CardContent>
							<div>

							<List component="nav" className={classes.root}>
							{values.screenshotdataaftersubmission.map((s_data, urlIndex) => (
								<ListItem key={urlIndex}>	
								<div style={{ display: 'flex' }}>
								<div style={{ display: 'flex', alignItems: 'center', flexDirection: 'column' }}>
								<Typography variant="body2" style={{ fontWeight: 'bold' }}>
								<a href={s_data.formurl} target="_blank" rel="noopener noreferrer">{s_data.formurl}</a>
								</Typography>
								<div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginTop: '10px' }}>
								<div style={{ display: 'flex', alignItems: 'center' }}>
								{values.screenshotdataaftersubmission && s_data.screenshot_before ?
									<img
									src={decodeBase64Image(s_data.screenshot_before)}
									alt={`Screenshot ${urlIndex}`}
									style={{ width: '150px', height: '50px' }}
									className={classes.image}
									onClick={() => {
										setIsBefore(true)
										handleClickImgOpen(urlIndex,0)
									}}
									/> :
									<img
									src={blankImageSource}
									alt={`Blank`}
									style={{ width: '150px', height: '50px' }}
									className={classes.image}
									/>
								}
								<ArrowRightAltIcon style={{ marginLeft: '2px', marginRight: '2px', color: 'black' }} />
								{values.screenshotdataaftersubmission && s_data.screenshot_after ?
									<img
									src={decodeBase64Image(s_data.screenshot_after)}
									alt={`Screenshot ${urlIndex}`}
									style={{ width: '150px', height: '50px' }}
									className={classes.image}
									onClick={() => {
										setIsBefore(false)
										handleClickImgOpen(urlIndex,1)
									}}
									/> :
									<img
									src={blankImageSource}
									alt={`Blank`}
									style={{ width: '150px', height: '50px' }}
									className={classes.image}
									/>
								}
								</div>
								</div>
								<Typography variant="body2" component = "p" style={{ marginTop: '5px', fontWeight: 'bold', color: (!values.formsubmitted || !values.fieldsvalidated) ? 'black' : s_data.difference === 'Yes' ? 'red' : 'green' }}>
								Visual Difference: {s_data.difference}	
								</Typography>
								{urlIndex === imgIndex && 
									<Dialog
									open={true}
									onClose={handleImgClose}
									fullWidth
									maxWidth="sm"
									PaperProps={{
										style: {
											overflowX: "hidden",
												minWidth: "fit-content",
										},
									}}
									>	
									<DialogActions style={{background:'aliceblue'}}>

									<div style={{display:'flex', alignItems: 'center', width:'100%'}}>
									<Typography variant="body2" component = "p" style={{ fontWeight: 'bold', color: 'black', marginLeft: '0' }}>
									{isBefore?"Before Form Submission":"After Form Submission"}
									</Typography>
									<HighlightOffIcon onClick={handleImgClose} style={{ marginLeft: '2px', color: 'black', marginLeft: 'auto' }} />
									</div>

									</DialogActions>
									<DialogContent>
									<DialogContentText>
									{imgDIndex === 0 &&
										<div>
										<img src={decodeBase64Image(s_data.screenshot_before)} alt={`Screenshot ${imgDIndex}`} />
										</div>
									}
									{imgDIndex != 0 &&
											<div>	
											<img src={decodeBase64Image(s_data.screenshot_after)} alt={`Screenshot ${imgDIndex}`} />
											</div>
									}
									</DialogContentText>
									</DialogContent>
									<DialogActions style={{justifyContent: 'center', background:'aliceblue'}}>

									<div style={{display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
									{ s_data.screenshot_before ?
										<Button 
										onClick={() => {
											handleToggleClick(1)
											setIsBefore(true)
										}} 
										color="black" disabled={isBefore}>
										<ArrowLeftIcon />	
										</Button> :
										<Button 
										color="black" disabled={true}>
										<ArrowLeftIcon />	
										</Button>
									}
									{ s_data.screenshot_after ?
											<Button	
										onClick={() => {
											handleToggleClick(0)
											setIsBefore(false)
										}} 
										color="black" disabled={!isBefore}>
											<ArrowRightIcon />	
											</Button> :
											<Button 
										color="black" disabled={true}>
											<ArrowRightIcon />	
											</Button>
									}
									</div>
									</DialogActions>
									</Dialog>
								}
								</div>	
								</div>
								</ListItem>
							))}
						</List>

						</div>

						</CardContent>
						</Card>
						</Collapse>
						</div>
						</div>
						</div>
						</Collapse>
						</CardContent>
						</Card>
						//))
					))
				)	
		}
		</div>
		</div>
	);
};

function decodeBase64Image(base64Image) {
	const decodedImage = atob(base64Image);
	const imageType = 'image/png'; // Change this to the appropriate image type
	const length = decodedImage.length;
	const uintArray = new Uint8Array(length);
	for (let i = 0; i < length; i++) {
		uintArray[i] = decodedImage.charCodeAt(i);
	}
	const blob = new Blob([uintArray], { type: imageType });
	const imageUrl = URL.createObjectURL(blob);
	return imageUrl;
}

export default SearchBox;

